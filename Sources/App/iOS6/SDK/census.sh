#!/bin/bash
# Type-checks VLC's iOS Swift sources with Embedded Swift against the iOS 6
# SDK overlays, and summarizes the errors left: the port's to-do list.
#
#   census.sh [build dir]
#
# Needs SWIFT_IOS6 (a Swift-iOS6 checkout, with `make -C ObjC macros` done)
# and FOUNDATION_EMBEDDED (a swift-embedded-foundation checkout).

set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
BUILD="${1:-$ROOT/build/iOS6/census}"
SWIFT_IOS6="${SWIFT_IOS6:-$ROOT/../Swift-iOS6}"
FOUNDATION_EMBEDDED="${FOUNDATION_EMBEDDED:-$ROOT/../swift-embedded-foundation}"
TOOLCHAIN="${SWIFT_TOOLCHAIN:-$HOME/Library/Developer/Toolchains/swift-6.4.2-RELEASE.xctoolchain}"
MODULES="$BUILD/modules"
mkdir -p "$MODULES"

swiftc() {
    "$TOOLCHAIN/usr/bin/swiftc" -target armv7-apple-none-macho \
        -enable-experimental-feature Embedded -wmo -Osize \
        -Xcc -marm -Xcc -ffixed-r9 \
        -I"$SWIFT_IOS6/ObjC/include" -I"$HERE/CVLCiOS6/include" -I"$MODULES" \
        -load-plugin-library "$SWIFT_IOS6/ObjC/build/plugins/libObjCMacros.dylib" "$@"
}

module() {
    local name="$1"; shift
    echo "module $name" >&2
    swiftc -parse-as-library -module-name "$name" -emit-module \
        -emit-module-path "$MODULES/$name.swiftmodule" "$@"
}

module ObjCInterop "$SWIFT_IOS6/ObjC/Sources/ObjCInterop.swift"
module Foundation "$SWIFT_IOS6"/Frameworks/Foundation/Sources/*.swift \
    "$FOUNDATION_EMBEDDED"/Sources/FoundationEmbedded/*.swift "$HERE"/Foundation/*.swift
module UIKit "$SWIFT_IOS6"/Frameworks/UIKit/Sources/*.swift "$HERE"/UIKit/*.swift
module SwiftUI "$SWIFT_IOS6"/SwiftUI/Sources/SwiftUI/*.swift \
    -I"$SWIFT_IOS6/SwiftUI/Sources/CSwiftUIBackend/include"
module VLCiOS6 "$HERE"/VLCiOS6/*.swift

# Frameworks VLC imports that iOS 6 or Embedded Swift doesn't have: empty
# stand-ins, so the errors name what's used of them
STUB="$BUILD/stub.swift"
echo "public enum _NotOnIOS6 {}" > "$STUB"
for name in $(cd "$ROOT" && find Sources -name '*.swift' -not -path 'Sources/App/iOS6/*' -print0 |
              xargs -0 grep -hE '^(@[A-Za-z_]+ )*import ' | sed -E 's/^(@[A-Za-z_]+ )*import //' |
              awk '{print $1}' | sort -u); do
    [ -e "$MODULES/$name.swiftmodule" ] && continue
    swiftc -parse-as-library -module-name "$name" -emit-module \
        -emit-module-path "$MODULES/$name.swiftmodule" "$STUB" 2>/dev/null || true
done

# The iOS app's Swift
cd "$ROOT"
find Sources -name '*.swift' -not -path 'Sources/App/iOS6/*' -not -path '*watchOS*' \
    -not -path '*tvOS*' -not -path '*CarPlay*' -not -path '*Widget*' -print0 > "$BUILD/sources"
set +e
xargs -0 "$TOOLCHAIN/usr/bin/swiftc" -target armv7-apple-none-macho \
    -enable-experimental-feature Embedded -wmo -Xcc -marm -Xcc -ffixed-r9 \
    -I"$SWIFT_IOS6/ObjC/include" -I"$HERE/CVLCiOS6/include" -I"$MODULES" \
    -I"$SWIFT_IOS6/SwiftUI/Sources/CSwiftUIBackend/include" \
    -load-plugin-library "$SWIFT_IOS6/ObjC/build/plugins/libObjCMacros.dylib" \
    -Xfrontend -import-module -Xfrontend VLCiOS6 \
    -parse-as-library -module-name VLC -typecheck < "$BUILD/sources" > "$BUILD/errors.txt" 2>&1
set -e

echo "$(tr '\0' '\n' < "$BUILD/sources" | wc -l | tr -d ' ') files, $(grep -cE '^Sources/.*: error: ' "$BUILD/errors.txt") errors"
echo "files with errors: $(grep -E '^Sources/.*\.swift:[0-9]+:[0-9]+: error: ' "$BUILD/errors.txt" | cut -d: -f1 | sort -u | wc -l | tr -d ' ')"
echo
echo "by kind:"
grep -oE " error: .*" "$BUILD/errors.txt" | sed -E "s/'[^']*'/X/g" | sort | uniq -c | sort -rn | head -15
echo
echo "most wanted names:"
grep -oE "error: cannot find (type )?'[^']+' in scope" "$BUILD/errors.txt" | grep -oE "'[^']+'" |
    sort | uniq -c | sort -rn | head -40 | awk '{printf "%s %s  ", $1, $2} END {print ""}'
