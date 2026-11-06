#!/bin/bash
# Regenerates the SDK's Swift wrappers for MobileVLCKit (as the module VLCKit,
# which VLC's sources import) and VLCMediaLibraryKit, from the iOS 6 builds'
# headers, with Swift-iOS6's ObjC/tools/objcgen.py. Like Swift-iOS6's own
# Foundation and UIKit modules, members newer than iOS 6.0 are left out.
#
#   generate.sh
#
# SWIFT_IOS6, VLCKIT (VLCKit's swift-ios6 branch, after
# ./buildMobileVLCKit.sh -6) and VLCMEDIALIBRARYKIT (after iOS6/build.sh)
# default to checkouts beside this repository.

set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
SWIFT_IOS6="${SWIFT_IOS6:-$ROOT/../Swift-iOS6}"
VLCKIT="${VLCKIT:-$ROOT/../VLCKit-iOS6-3}"
VLCMEDIALIBRARYKIT="${VLCMEDIALIBRARYKIT:-$ROOT/../VLCMediaLibraryKit-iOS6}"

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

python3 -I "$SWIFT_IOS6/ObjC/tools/objcgen.py" \
    --framework Foundation --framework UIKit \
    --framework MobileVLCKit --framework VLCMediaLibraryKit \
    --framework-path "$VLCKIT/build/iOS6" \
    --framework-path "$VLCMEDIALIBRARYKIT/build/iOS6" \
    --sdk "$SWIFT_IOS6/sdk/iPhoneOS9.3.sdk" --out "$OUT"

mkdir -p "$HERE/VLCKit" "$HERE/VLCMediaLibraryKit"
# VLC's sources import VLCKit: it's the same API, from VLCKit 3 here
sed -e 's|^// MobileVLCKit for Embedded Swift|// MobileVLCKit (as VLCKit) for Embedded Swift|' \
    -e 's|regenerate with `make frameworks` in ObjC/|regenerate with SDK/generate.sh|' \
    "$OUT/MobileVLCKit/Sources/MobileVLCKit.swift" > "$HERE/VLCKit/VLCKit.swift"
sed -e 's|regenerate with `make frameworks` in ObjC/|regenerate with SDK/generate.sh|' \
    "$OUT/VLCMediaLibraryKit/Sources/VLCMediaLibraryKit.swift" > "$HERE/VLCMediaLibraryKit/VLCMediaLibraryKit.swift"

# Swift's is… names for the Boolean properties (isHidden, isEnabled…)
python3 -I "$HERE/isnames.py" "$SWIFT_IOS6/Frameworks/Foundation/Sources/Foundation.swift" Foundation \
    "$HERE/Foundation/Foundation+IsNames.swift"
python3 -I "$HERE/isnames.py" "$SWIFT_IOS6/Frameworks/UIKit/Sources/UIKit.swift" UIKit \
    "$HERE/UIKit/UIKit+IsNames.swift"
python3 -I "$HERE/isnames.py" "$HERE/VLCKit/VLCKit.swift" VLCKit "$HERE/VLCKit/VLCKit+IsNames.swift"
python3 -I "$HERE/isnames.py" "$HERE/VLCMediaLibraryKit/VLCMediaLibraryKit.swift" VLCMediaLibraryKit \
    "$HERE/VLCMediaLibraryKit/VLCMediaLibraryKit+IsNames.swift"
