#!/bin/bash
# Regenerates the SDK's Swift wrappers for MobileVLCKit (as the module VLCKit,
# which VLC's sources import) and VLCMediaLibraryKit, from the iOS 6 builds'
# headers, and for the app's own Objective-C classes (the module VLCApp), from
# the headers VLC-iOS-Bridging-Header.h imports, with Swift-iOS6's
# ObjC/tools/objcgen.py. Like Swift-iOS6's own Foundation and UIKit modules,
# members newer than iOS 6.0 are left out. Then Swift's names for them all
# (swiftnames.py, isnames.py).
#
#   generate.sh
#
# SWIFT_IOS6, VLCKIT (VLCKit's swift-ios6 branch, after
# ./buildMobileVLCKit.sh -6), VLCMEDIALIBRARYKIT (after iOS6/build.sh) and
# FOUNDATION_EMBEDDED (swift-embedded-foundation) default to checkouts beside
# this repository.

set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
SWIFT_IOS6="${SWIFT_IOS6:-$ROOT/../Swift-iOS6}"
VLCKIT="${VLCKIT:-$ROOT/../VLCKit-iOS6-3}"
VLCMEDIALIBRARYKIT="${VLCMEDIALIBRARYKIT:-$ROOT/../VLCMediaLibraryKit-iOS6}"
FOUNDATION_EMBEDDED="${FOUNDATION_EMBEDDED:-$ROOT/../swift-embedded-foundation}"

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

# The app's headers, as a framework: VLCApp.h has what VLC-iOS-Prefix-Header.pch
# and the iOS part of VLC-iOS-Bridging-Header.h import
APP="$OUT/frameworks/VLCApp.framework/Headers"
mkdir -p "$APP" "$OUT/frameworks/VLCKit.framework/Headers"
(cd "$ROOT" && find Sources -name '*.h' -not -path 'Sources/App/iOS6/*' -not -path '*tvOS*' \
    -not -path '*watchOS*' -print0) | while IFS= read -r -d '' header; do
    ln -sf "$ROOT/$header" "$APP/"
done
# The app's headers import VLCKit, which is MobileVLCKit here
echo '#import <MobileVLCKit/MobileVLCKit.h>' > "$OUT/frameworks/VLCKit.framework/Headers/VLCKit.h"
for name in VLCKit VLCApp; do
    mkdir -p "$OUT/frameworks/$name.framework/Modules"
    printf 'framework module %s {\n    umbrella header "%s.h"\n    export *\n}\n' "$name" "$name" \
        > "$OUT/frameworks/$name.framework/Modules/module.modulemap"
done
# OBSlider (a pod) is VLCOBSlider's superclass
printf '@interface OBSlider : UISlider\n@end\n' > "$APP/OBSlider.h"
{
    cat <<'EOF'
#import <UIKit/UIKit.h>
#import <VLCKit/VLCKit.h>
#ifndef API_AVAILABLE
#define API_AVAILABLE(...)
#define API_UNAVAILABLE(...)
#define API_DEPRECATED(...)
#define API_DEPRECATED_WITH_REPLACEMENT(...)
#endif
#define APLog(format, ...)
#define VISIONOS_API_AVAILABLE
#define VISIONOS_AVAILABLE
// VLCKit 4's, which VLCKit 3 doesn't have
@class VLCMediaParser, UIMenuElement;
typedef NSInteger VLCMediaListSortCriteria;
#import "VLCConstants.h"
#import "UIBarButtonItem+Theme.h"
#import "UIViewController+VLCAlert.h"
EOF
    # UIStackView+Orientation.h extends UIWindowScene (iOS 13)
    awk '/^#if TARGET_OS_IOS/ { exit } /^#import "/' "$ROOT/Sources/Headers/VLC-iOS-Bridging-Header.h" |
        grep -v 'UIStackView+Orientation.h'
} > "$APP/VLCApp.h"

python3 -I "$SWIFT_IOS6/ObjC/tools/objcgen.py" \
    --framework Foundation --framework UIKit \
    --framework MobileVLCKit --framework VLCMediaLibraryKit --framework VLCApp \
    --framework-path "$VLCKIT/build/iOS6" \
    --framework-path "$VLCMEDIALIBRARYKIT/build/iOS6" \
    --framework-path "$OUT/frameworks" \
    --sdk "$SWIFT_IOS6/sdk/iPhoneOS9.3.sdk" --out "$OUT"

mkdir -p "$HERE/VLCKit" "$HERE/VLCMediaLibraryKit" "$HERE/VLCApp"
# VLC's sources import VLCKit: it's the same API, from VLCKit 3 here
sed -e 's|^// MobileVLCKit for Embedded Swift|// MobileVLCKit (as VLCKit) for Embedded Swift|' \
    -e 's|regenerate with `make frameworks` in ObjC/|regenerate with SDK/generate.sh|' \
    "$OUT/MobileVLCKit/Sources/MobileVLCKit.swift" > "$HERE/VLCKit/VLCKit.swift"
sed -e 's|regenerate with `make frameworks` in ObjC/|regenerate with SDK/generate.sh|' \
    "$OUT/VLCMediaLibraryKit/Sources/VLCMediaLibraryKit.swift" > "$HERE/VLCMediaLibraryKit/VLCMediaLibraryKit.swift"
sed -e 's|^import MobileVLCKit$|import VLCKit|' \
    -e "s|^// from the iOS SDK's headers. Don't edit: regenerate with \`make frameworks\` in ObjC/.|// from the app's headers. Don't edit: regenerate with SDK/generate.sh.|" \
    "$OUT/VLCApp/Sources/VLCApp.swift" > "$HERE/VLCApp/VLCApp.swift"

# Swift's names for methods, properties and classes (present(_:animated:completion:),
# UIColor.white, PlaybackService…), from the symbol graphs of the current iOS
# SDK and of the frameworks' and the app's headers
python3 -I "$HERE/selectors.py" "$HERE/selectors.json" -F "$VLCKIT/build/iOS6" -F "$VLCMEDIALIBRARYKIT/build/iOS6" \
    -F "$OUT/frameworks" MobileVLCKit VLCMediaLibraryKit VLCApp
python3 -I "$HERE/swiftnames.py" "$HERE/selectors.json" "$SWIFT_IOS6/Frameworks/Foundation/Sources/Foundation.swift" \
    Foundation "$HERE/Foundation/Foundation+SwiftNames.swift" "$HERE"/Foundation/*.swift \
    "$FOUNDATION_EMBEDDED"/Sources/FoundationEmbedded/*.swift
python3 -I "$HERE/swiftnames.py" "$HERE/selectors.json" "$SWIFT_IOS6/Frameworks/UIKit/Sources/UIKit.swift" \
    UIKit "$HERE/UIKit/UIKit+SwiftNames.swift" "$HERE"/UIKit/*.swift
python3 -I "$HERE/swiftnames.py" "$HERE/selectors.json" "$HERE/VLCKit/VLCKit.swift" VLCKit "$HERE/VLCKit/VLCKit+SwiftNames.swift"
python3 -I "$HERE/swiftnames.py" "$HERE/selectors.json" "$HERE/VLCMediaLibraryKit/VLCMediaLibraryKit.swift" \
    VLCMediaLibraryKit "$HERE/VLCMediaLibraryKit/VLCMediaLibraryKit+SwiftNames.swift"
python3 -I "$HERE/swiftnames.py" "$HERE/selectors.json" "$HERE/VLCApp/VLCApp.swift" VLCApp "$HERE/VLCApp/VLCApp+SwiftNames.swift"

# Swift's is… names for the Boolean properties (isHidden, isEnabled…)
python3 -I "$HERE/isnames.py" "$SWIFT_IOS6/Frameworks/Foundation/Sources/Foundation.swift" Foundation \
    "$HERE/Foundation/Foundation+IsNames.swift"
python3 -I "$HERE/isnames.py" "$SWIFT_IOS6/Frameworks/UIKit/Sources/UIKit.swift" UIKit \
    "$HERE/UIKit/UIKit+IsNames.swift"
python3 -I "$HERE/isnames.py" "$HERE/VLCKit/VLCKit.swift" VLCKit "$HERE/VLCKit/VLCKit+IsNames.swift"
python3 -I "$HERE/isnames.py" "$HERE/VLCMediaLibraryKit/VLCMediaLibraryKit.swift" VLCMediaLibraryKit \
    "$HERE/VLCMediaLibraryKit/VLCMediaLibraryKit+IsNames.swift"
python3 -I "$HERE/isnames.py" "$HERE/VLCApp/VLCApp.swift" VLCApp "$HERE/VLCApp/VLCApp+IsNames.swift"
