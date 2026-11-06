/*****************************************************************************
 * VLCKit.swift
 * VLC for iOS 6
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

// MobileVLCKit's Objective-C API for Embedded Swift, which has no Objective-C
// interop of its own: typed wrappers whose members send the messages
// (ObjCInterop's @ObjC macros). Only what the iOS 6 app uses is declared.
// The framework is VLCKit 3 built for iOS 6 (VLCKit's swift-ios6 branch).

import Foundation
import ObjCInterop

/// VLCMediaPlayerState
enum VLCMediaPlayerState: Int {
    case stopped = 0
    case opening
    case buffering
    case ended
    case error
    case playing
    case paused
    case esAdded
}

@ObjC("VLCTime")
struct VLCTime {
    /// "1:23", or "--:--" for no time
    @ObjCProperty(readonly: true) var stringValue: String
    /// milliseconds
    @ObjCProperty(readonly: true) var intValue: Int
}

@ObjC("VLCMedia")
struct VLCMedia {
    @ObjCMethod static func mediaWithPath(_ path: String) -> VLCMedia
    @ObjCMethod static func mediaWithURL(_ url: NSURL) -> VLCMedia
    @ObjCProperty(readonly: true) var length: VLCTime
}

@ObjC("VLCMediaPlayer")
struct VLCMediaPlayer {
    @ObjCMethod init()

    @ObjCProperty var media: VLCMedia?
    /// The UIView the video is drawn into.
    @ObjCProperty var drawable: ObjCValue

    @ObjCMethod func play()
    @ObjCMethod func pause()
    @ObjCMethod func stop()
    @ObjCMethod func jumpForward(_ seconds: Int)
    @ObjCMethod func jumpBackward(_ seconds: Int)

    @ObjCProperty(getter: "isPlaying", readonly: true) var playing: Bool
    @ObjCProperty(getter: "isSeekable", readonly: true) var seekable: Bool
    @ObjCProperty(readonly: true) var state: Int
    /// 0 to 1
    @ObjCProperty var position: Float
    @ObjCProperty(readonly: true) var time: VLCTime
    @ObjCProperty(readonly: true) var remainingTime: VLCTime
    @ObjCProperty(readonly: true) var videoSize: CGSize
}

extension VLCMediaPlayer {
    var playerState: VLCMediaPlayerState {
        VLCMediaPlayerState(rawValue: state) ?? .error
    }

    /// "16:9" and the like, or nil for the video's own (a C string in VLCKit)
    func setVideoAspectRatio(_ ratio: String?) {
        if let ratio {
            _ = object.send("setVideoAspectRatio:", ratio)
        } else {
            _ = object.send("setVideoAspectRatio:", ObjC.nil)
        }
    }
}

@ObjC("VLCLibrary")
struct VLCLibrary {
    @ObjCMethod static func sharedLibrary() -> VLCLibrary
    @ObjCProperty(readonly: true) var version: String
    /// VLCLogging objects that receive libvlc's log
    @ObjCProperty var loggers: NSArray?
}

/// Writes libvlc's log to a file
@ObjC("VLCFileLogger")
struct VLCFileLogger {
    @ObjCMethod init(fileHandle: NSFileHandle)
    /// VLCLogLevel: 0 errors, 1 warnings, 2 info, 3 debug
    @ObjCProperty var level: Int
}
