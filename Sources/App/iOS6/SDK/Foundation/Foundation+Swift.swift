/*****************************************************************************
 * Foundation+Swift.swift
 * VLC for iOS 6
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

// Foundation's Swift API for VLC's sources, built with Embedded Swift for
// iOS 6. The module combines Swift-iOS6's Objective-C wrappers (NSBundle,
// NSUserDefaults…), swift-embedded-foundation's value types (URL, Data,
// Date, IndexPath…) and this overlay, which gives the classes Foundation's
// Swift names and spelling on top of the wrappers.

@_exported import ObjCInterop
import CVLCiOS6

// MARK: - Types

/// float on armv7
public typealias CGFloat = Float
// TimeInterval comes from swift-embedded-foundation

// MARK: - Localization

public func NSLocalizedString(_ key: String, tableName: String? = nil, bundle: Bundle = .main,
                              value: String = "", comment: String) -> String {
    bundle.bundle.localizedStringForKey(key, value: value, table: tableName)
}

// MARK: - Bundle

public struct Bundle {
    public let bundle: NSBundle

    public init(_ bundle: NSBundle) { self.bundle = bundle }

    public static var main: Bundle { Bundle(NSBundle.mainBundle()) }

    public var bundleIdentifier: String? { bundle.object.bundleIdentifier().asString }
    public var bundlePath: String { bundle.object.bundlePath().asString ?? "" }
    public var resourcePath: String? { bundle.object.resourcePath().asString }

    public func object(forInfoDictionaryKey key: String) -> ObjCValue? {
        let value = bundle.objectForInfoDictionaryKey(key)
        return value.isNil ? nil : value
    }

    public func path(forResource name: String?, ofType ext: String?) -> String? {
        bundle.pathForResource(name, ofType: ext)
    }
}

// MARK: - UserDefaults

public struct UserDefaults {
    public let defaults: NSUserDefaults

    public init(_ defaults: NSUserDefaults) { self.defaults = defaults }

    public static var standard: UserDefaults { UserDefaults(NSUserDefaults.standardUserDefaults()) }

    public func bool(forKey key: String) -> Bool { defaults.boolForKey(key) }
    public func integer(forKey key: String) -> Int { defaults.integerForKey(key) }
    public func double(forKey key: String) -> Double { defaults.doubleForKey(key) }
    public func float(forKey key: String) -> Float { Float(defaults.doubleForKey(key)) }
    public func string(forKey key: String) -> String? { defaults.stringForKey(key) }

    public func object(forKey key: String) -> ObjCValue? {
        let value = defaults.objectForKey(key)
        return value.isNil ? nil : value
    }

    public func set(_ value: Bool, forKey key: String) { defaults.setBool(value, forKey: key) }
    public func set(_ value: Int, forKey key: String) { defaults.setInteger(value, forKey: key) }
    public func set(_ value: Double, forKey key: String) { defaults.setDouble(value, forKey: key) }
    public func set(_ value: Float, forKey key: String) { defaults.setDouble(Double(value), forKey: key) }

    public func set(_ value: String?, forKey key: String) {
        if let value {
            defaults.setObject(ObjCValue(value), forKey: key)
        } else {
            defaults.removeObjectForKey(key)
        }
    }

    public func set(_ value: ObjCValue?, forKey key: String) {
        if let value, !value.isNil {
            defaults.setObject(value, forKey: key)
        } else {
            defaults.removeObjectForKey(key)
        }
    }

    public func removeObject(forKey key: String) { defaults.removeObjectForKey(key) }

    @discardableResult
    public func synchronize() -> Bool { defaults.object.synchronize().asBool ?? false }
}

// MARK: - Notifications

public struct Notification {
    public struct Name: RawRepresentable, Hashable, ExpressibleByStringLiteral {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public init(stringLiteral value: String) { self.rawValue = value }
    }

    public let name: Name
    public let object: ObjCValue?
    public let userInfo: NSDictionary?

    public init(name: Name, object: ObjCValue? = nil, userInfo: NSDictionary? = nil) {
        self.name = name
        self.object = object
        self.userInfo = userInfo
    }

    /// A notification Objective-C delivered
    public init(_ notification: ObjCValue) {
        name = Name(rawValue: notification.name().asString ?? "")
        let object = notification.object()
        self.object = object.isNil ? nil : object
        let userInfo = notification.userInfo()
        self.userInfo = userInfo.isNil ? nil : NSDictionary(userInfo)
    }
}

public struct NotificationCenter {
    public let center: NSNotificationCenter

    public init(_ center: NSNotificationCenter) { self.center = center }

    public static var `default`: NotificationCenter { NotificationCenter(NSNotificationCenter.defaultCenter()) }

    public func post(name: Notification.Name, object: ObjCValue? = nil, userInfo: NSDictionary? = nil) {
        center.postNotificationName(name.rawValue, object: object ?? ObjC.nil, userInfo: userInfo)
    }

    public func post(_ notification: Notification) {
        post(name: notification.name, object: notification.object, userInfo: notification.userInfo)
    }

    /// An Objective-C observer: `selector` is its method's name, as
    /// `#selector` gives it in Objective-C.
    public func addObserver(_ observer: ObjCValue, selector: String, name: Notification.Name?, object: ObjCValue?) {
        center.addObserver(observer, selector: ObjC.selector(selector), name: name?.rawValue, object: object ?? ObjC.nil)
    }

    /// Calls `block` on the main queue for each notification. Returns the
    /// observer to pass to removeObserver(_:).
    @discardableResult
    public func addObserver(forName name: Notification.Name?, object: ObjCValue?,
                            using block: @escaping (Notification) -> Void) -> ObjCValue {
        let handler = ObjCBlock(types: "v@") { call in
            block(Notification(call[0]))
            return nil
        }
        return center.object.send("addObserverForName:object:queue:usingBlock:",
                                  name?.rawValue, object ?? ObjC.nil,
                                  ObjC.NSOperationQueue.mainQueue(), handler)
    }

    public func removeObserver(_ observer: ObjCValue) { center.removeObserver(observer) }

    public func removeObserver(_ observer: ObjCValue, name: Notification.Name?, object: ObjCValue?) {
        center.removeObserver(observer, name: name?.rawValue, object: object ?? ObjC.nil)
    }
}

// MARK: - FileManager

/// FileManager's errors, as Embedded Swift has no untyped throws
public struct CocoaError: Error {
    public let description: String
    public init(_ description: String) { self.description = description }
}

public struct FileManager {
    public let manager: NSFileManager

    public init(_ manager: NSFileManager) { self.manager = manager }

    public static var `default`: FileManager { FileManager(NSFileManager.defaultManager()) }

    public func fileExists(atPath path: String) -> Bool { manager.fileExistsAtPath(path) }

    public func createDirectory(atPath path: String, withIntermediateDirectories: Bool,
                                attributes: NSDictionary? = nil) throws(CocoaError) {
        if !manager.createDirectoryAtPath(path, withIntermediateDirectories: withIntermediateDirectories,
                                          attributes: attributes, error: ObjC.nil) {
            throw CocoaError("couldn't create \(path)")
        }
    }

    public func removeItem(atPath path: String) throws(CocoaError) {
        if !manager.removeItemAtPath(path, error: ObjC.nil) { throw CocoaError("couldn't remove \(path)") }
    }

    public func moveItem(atPath source: String, toPath destination: String) throws(CocoaError) {
        if !manager.moveItemAtPath(source, toPath: destination, error: ObjC.nil) {
            throw CocoaError("couldn't move \(source)")
        }
    }

    public func copyItem(atPath source: String, toPath destination: String) throws(CocoaError) {
        if !manager.copyItemAtPath(source, toPath: destination, error: ObjC.nil) {
            throw CocoaError("couldn't copy \(source)")
        }
    }

    public func contentsOfDirectory(atPath path: String) throws(CocoaError) -> [String] {
        guard let names = manager.contentsOfDirectoryAtPath(path, error: ObjC.nil) else {
            throw CocoaError("couldn't list \(path)")
        }
        var result: [String] = []
        for index in 0..<names.count {
            if let name = names.objectAtIndex(index).asString { result.append(name) }
        }
        return result
    }
}

// MARK: - Dispatch

/// A point in time, in nanoseconds since boot
public struct DispatchTime: Comparable {
    public let uptimeNanoseconds: UInt64

    public init(uptimeNanoseconds: UInt64) { self.uptimeNanoseconds = uptimeNanoseconds }

    public static func now() -> DispatchTime { DispatchTime(uptimeNanoseconds: vlc6_uptime_nanoseconds()) }

    public static func + (time: DispatchTime, seconds: Double) -> DispatchTime {
        DispatchTime(uptimeNanoseconds: time.uptimeNanoseconds + UInt64(seconds * 1_000_000_000))
    }

    public static func < (a: DispatchTime, b: DispatchTime) -> Bool { a.uptimeNanoseconds < b.uptimeNanoseconds }
}

public enum DispatchQoS {
    public enum QoSClass { case background, utility, `default`, userInitiated, userInteractive, unspecified }
}

/// The main queue, and the global ones: what VLC uses of Dispatch
public struct DispatchQueue {
    private let isMain: Bool
    private let priority: Int

    public static let main = DispatchQueue(isMain: true, priority: 0)

    public static func global(qos: DispatchQoS.QoSClass = .default) -> DispatchQueue {
        switch qos {
        case .background: return DispatchQueue(isMain: false, priority: -32768) // DISPATCH_QUEUE_PRIORITY_BACKGROUND
        case .utility: return DispatchQueue(isMain: false, priority: -2) // LOW
        case .userInitiated, .userInteractive: return DispatchQueue(isMain: false, priority: 2) // HIGH
        case .default, .unspecified: return DispatchQueue(isMain: false, priority: 0)
        }
    }

    public func async(execute work: @escaping () -> Void) {
        let context = Unmanaged.passRetained(DispatchWork(work)).toOpaque()
        if isMain {
            objcrt_async(runDispatchWork, context)
        } else {
            vlc6_dispatch_global_async(priority, runDispatchWork, context)
        }
    }

    public func asyncAfter(deadline: DispatchTime, execute work: @escaping () -> Void) {
        let now = DispatchTime.now()
        let milliseconds = deadline > now ? UInt((deadline.uptimeNanoseconds - now.uptimeNanoseconds) / 1_000_000) : 0
        let context = Unmanaged.passRetained(DispatchWork(work)).toOpaque()
        if isMain {
            objcrt_after(milliseconds, runDispatchWork, context)
        } else {
            vlc6_dispatch_global_after(priority, milliseconds, runDispatchWork, context)
        }
    }
}

private final class DispatchWork {
    let work: () -> Void
    init(_ work: @escaping () -> Void) { self.work = work }
}

private func runDispatchWork(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    Unmanaged<DispatchWork>.fromOpaque(context).takeRetainedValue().work()
}
