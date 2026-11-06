# VLC for iOS 6

VLC for armv7 devices on iOS 6 (iPod touch 4, iPhone 4/4S, iPad 2), in
Embedded Swift. It lists the media in the app's Documents folder and plays
it with MobileVLCKit (VLCKit 3, libvlc 3.0) in a full-screen player with
play/pause, 10 second jumps, seeking and VLC's aspect ratios.

It's built with [Swift-iOS6](https://github.com/colemancda/Swift-iOS6)'s
toolchain setup (Xcode's clang and ld, the swift.org Embedded stdlib, the
iOS 9.3 SDK checked against iOS 6.0), its SwiftUI library and its typed
Foundation and UIKit modules, and with the iOS 6 build of MobileVLCKit from
VLCKit's [swift-ios6](https://github.com/MillerTechnologyPeru/vlckit/tree/swift-ios6)
branch.

```bash
# once: ../Swift-iOS6 with `make sdk`, ../VLCKit-iOS6-3 on swift-ios6 with
# `./buildMobileVLCKit.sh -6` (see its Packaging/iOS6/README.md)
make                                  # build/iOS6/VLCiOS6.app
make install                          # to a jailbroken device over SSH
make media FILES="movie.mp4 song.mp3" # into the app's Documents
make run
```

`SWIFT_IOS6`, `VLCKIT`, `SSH_CONF` and `SSH_HOST` point elsewhere.

For looking into problems on the device, which keeps no syslog:

```bash
make log                    # the app's and libvlc's warnings, Documents/VLC.log
make autoplay FILE=a.mp4    # launch and play a file, without touching the device
```

`make run` and `make autoplay` need the device unlocked. Documents must
belong to `mobile` (`make media` sees to it), or the app can't write there.

## How it's put together

- **`VLCiOS6App.swift`:** the app and the media list, in SwiftUI. The list
  rereads Documents every 2 seconds, as iTunes file sharing adds files.
- **`PlayerViewController.swift`:** the player, in UIKit: a
  `UIViewController` subclass defined in Swift with
  `@ObjCImplementation`, whose overrides and control actions UIKit calls.
  iOS 6 has no layout anchors, so frames and autoresizing masks lay it out.
- **`VLCKit.swift`:** MobileVLCKit's API for Swift, as `@ObjC` wrappers
  (`VLCMediaPlayer`, `VLCMedia`, `VLCTime`). Embedded Swift has no
  Objective-C interop; the macros generate the messages.
- **`DebugLog.swift`:** the log file, with libvlc's messages through a
  VLCKit logger implemented in Swift.
- **`Localization.swift`:** `NSLocalizedString` on `NSBundle`, so the
  screens and shared code use VLC's `Localizable.strings`.
- **Shared with the iOS app:** `AspectRatio.swift` and `Array+Safety.swift`
  build for both. Where they need Objective-C (`@objc`), that part is behind
  `#if !hasFeature(Embedded)`.

The Makefile links MobileVLCKit with `-ObjC` (Swift reaches its classes by
name only), against iOS 6's own link stubs, and checks the app's imports
against what iOS 6.1.6 exports before it's installed. The app is about 40 MB,
more than an iPod's system partition usually has free, so `make install`
puts it in `/var/stash/Applications` with a link in `/Applications`.

## Porting the iOS app

`SDK/` is the start of an iOS 6 SDK for VLC's own iOS sources, in Embedded
Swift. Its `Foundation` module combines Swift-iOS6's Objective-C wrappers,
[swift-embedded-foundation](https://github.com/PureSwift/swift-embedded-foundation)'s
value types (`URL`, `Data`, `Date`, `IndexPath`…) and an overlay with
Foundation's Swift API for the classes (`Bundle`, `UserDefaults`,
`NotificationCenter`, `FileManager`, `DispatchQueue`, `NSLocalizedString`).
`UIKit` re-exports it, and `VLCiOS6` is imported into every file in place of
the bridging header.

`SDK/generate.sh` writes the wrappers for VLCKit, VLCMediaLibraryKit and
`VLCApp`: the app's own Objective-C classes (`VLCPlaybackService`,
`VLCAppCoordinator`…), from the headers the bridging header imports. Then it
gives them, and Foundation's and UIKit's, Swift's names: objcgen.py names
members after their selectors (`presentViewController(_:animated:completion:)`,
`UIColor.whiteColor()`), so `SDK/swiftnames.py` adds members with the names
Swift gives them (`present(_:animated:completion:)`, `UIColor.white`), and
type aliases for renamed classes (`PlaybackService`). The names come from the
symbol graphs `SDK/selectors.py` extracts into `SDK/selectors.json`.

`make census` type-checks the app's 192 iOS Swift files against it and
lists the errors left by kind and the names most wanted, counting errors in
macro expansions against the file they come from. It needs
swift-embedded-foundation beside this repository (or `FOUNDATION_EMBEDDED`).

VLC's classes went through `SDK/port.py` (`python3 SDK/port.py <repository>`),
which rewrites them for ObjCInterop's `@ObjCImplementation`:

- `class Cell: UITableViewCell, UITableViewDelegate` becomes
  `@ObjCImplementation(protocols: ["UITableViewDelegate"]) class Cell:
  UITableViewCellMethods`: a subclass of UITableViewCell, with its members.
  The subclasses of converted classes are converted too.
- Overrides and the methods of adopted Objective-C protocols, in the class
  or its extensions (`@ObjCExtension`), are exported with `@ObjCMethod` and
  their real selectors. Swift renames them
  (`tableView(_:cellForRowAt:)` is `tableView:cellForRowAtIndexPath:`), so
  `SDK/selectors.py` writes `SDK/selectors.json` from the current iOS SDK's
  symbol graphs.
- `super.m(…)` calls become `callSuper("m:", …)`, `super.init(…)` becomes
  `objcInit("init…", …)`, and initializers that relied on Swift's implicit
  `super.init()` call `objcInit()`.
- `@objc` becomes `@ObjCMethod`, and `#selector(m(_:))` becomes
  `ObjC.selector("m:")`.

It converted 159 classes and left 10 whose superclasses have no iOS 6
wrapper: UIStackView and UIAlertController, which are newer than iOS 6, and
the app's own Objective-C classes, which had no wrappers yet.
