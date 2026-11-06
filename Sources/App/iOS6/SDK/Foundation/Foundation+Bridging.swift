/*****************************************************************************
 * Foundation+Bridging.swift
 * VLC for iOS 6
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

// Swift's bridging of Foundation's value types to their Objective-C classes,
// for message arguments and results and the parameters of methods Swift
// exports (@ObjCMethod): IndexPath and NSIndexPath, URL and NSURL, Date and
// NSDate, and Notification and NSNotification.

extension IndexPath: ObjCConvertible, ObjCResult {
    public var objcValue: ObjCValue {
        guard count > 0 else { return NSIndexPath.objcClass.new() }
        var path = NSIndexPath.indexPathWithIndex(self[0])
        for position in 1..<count {
            path = path.indexPathByAddingIndex(self[position])
        }
        return path.object
    }

    public init(objcValue: ObjCValue) {
        guard !objcValue.isNil else {
            self.init()
            return
        }
        let path = NSIndexPath(objcValue)
        var indexes: [Int] = []
        for position in 0..<path.length {
            indexes.append(path.indexAtPosition(position))
        }
        self.init(indexes: indexes)
    }
}

extension URL: ObjCConvertible, ObjCResult {
    public var objcValue: ObjCValue { NSURL.URLWithString(absoluteString)?.object ?? ObjC.nil }

    /// A nil NSURL is an empty URL: optional parameters (URL?) are nil instead.
    public init(objcValue: ObjCValue) {
        let string = objcValue.isNil ? "" : NSURL(objcValue).absoluteString
        self = URL(string: string) ?? URL(string: "about:blank")!
    }
}

extension Date: ObjCConvertible, ObjCResult {
    public var objcValue: ObjCValue {
        NSDate.dateWithTimeIntervalSinceReferenceDate(timeIntervalSinceReferenceDate).object
    }

    public init(objcValue: ObjCValue) {
        self.init(timeIntervalSinceReferenceDate: objcValue.isNil ? 0 :
                    objcValue.send("timeIntervalSinceReferenceDate").asDouble ?? 0)
    }
}

extension Notification: ObjCConvertible, ObjCResult {
    public var objcValue: ObjCValue {
        NSNotification.notificationWithName(name.rawValue, object: object ?? ObjC.nil, userInfo: userInfo).object
    }

    public init(objcValue: ObjCValue) {
        self.init(objcValue)
    }
}
