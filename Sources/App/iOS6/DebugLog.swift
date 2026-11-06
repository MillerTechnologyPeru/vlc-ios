/*****************************************************************************
 * DebugLog.swift
 * VLC for iOS 6
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import Foundation
import ObjCInterop

/// The app's and libvlc's log, in Documents/VLC.log. iOS 6 devices keep no
/// syslog by default, and the app has no console, so this is how a failed
/// playback can be looked into (`make log`).
enum DebugLog {
    private static var handle: NSFileHandle?
    private static var start = NSDate.date().timeIntervalSinceReferenceDate
    /// libvlc's log goes through this object (a VLCLogging logger)
    private static var logger: ObjCValue?

    static func start(documents: String) {
        let path = documents + "/VLC.log"
        _ = NSFileManager.defaultManager().createFileAtPath(path, contents: nil, attributes: nil)
        guard let handle = NSFileHandle.fileHandleForWritingAtPath(path) else { return }
        self.handle = handle

        let library = VLCLibrary.sharedLibrary()
        let logger = LibVLCLogger.objcClass.alloc().send("init")
        self.logger = logger
        library.loggers = NSArray.arrayWithObject(logger)
        log("libvlc \(library.version)")
    }

    static func log(_ message: String) {
        write("[app] " + message)
    }

    /// A line, after the milliseconds since launch
    static func write(_ line: String) {
        let ms = Int((NSDate.date().timeIntervalSinceReferenceDate - start) * 1000)
        guard let handle,
              let data = NSString.stringWithString("\(ms) \(line)\n").dataUsingEncoding(4 /* UTF-8 */)
        else { return }
        _ = handle.seekToEndOfFile()
        handle.writeData(data)
    }
}

/// Receives libvlc's log from VLCKit (the VLCLogging protocol)
@ObjCImplementation("VLCiOS6LibVLCLogger")
final class LibVLCLogger {
    init() {}

    /// VLCLogLevel: 0 errors, 1 warnings, 2 info, 3 debug. Writing every
    /// debug message to flash slows playback down on an iPod.
    @ObjCMethod func level() -> Int { 1 }

    @ObjCMethod func setLevel(_ level: Int) {}

    @ObjCMethod("handleMessage:logLevel:context:")
    func handleMessage(_ message: String, logLevel: Int, context: ObjCValue) {
        DebugLog.write("[vlc] " + message)
    }
}
