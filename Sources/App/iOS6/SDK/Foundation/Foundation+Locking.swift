/*****************************************************************************
 * Foundation+Locking.swift
 * VLC for iOS 6
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

// The NSLocking protocol's -lock and -unlock: the generated wrappers only
// carry a class's own methods, not those of the protocols it adopts.

extension NSLockMethods {
    public func lock() { _ = object.send("lock") }
    public func unlock() { _ = object.send("unlock") }
}

extension NSRecursiveLockMethods {
    public func lock() { _ = object.send("lock") }
    public func unlock() { _ = object.send("unlock") }
}

extension NSConditionMethods {
    public func lock() { _ = object.send("lock") }
    public func unlock() { _ = object.send("unlock") }
}

extension NSConditionLockMethods {
    public func lock() { _ = object.send("lock") }
    public func unlock() { _ = object.send("unlock") }
}
