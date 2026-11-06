/*****************************************************************************
 * UIKit+Geometry.swift
 * VLC for iOS 6
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

// The Swift conveniences of Core Graphics' geometry and UIKit's IndexPath,
// which VLC's sources use: ObjCInterop's CGRect, CGSize and CGPoint only
// have their fields, and swift-embedded-foundation's IndexPath has no rows.

extension CGPoint {
    public static var zero: CGPoint { CGPoint(x: 0, y: 0) }
}

extension CGSize {
    public static var zero: CGSize { CGSize(width: 0, height: 0) }
}

extension CGRect {
    public static var zero: CGRect { CGRect(x: 0, y: 0, width: 0, height: 0) }

    public init(origin: CGPoint, size: CGSize) {
        self.init(x: origin.x, y: origin.y, width: size.width, height: size.height)
    }

    public var width: CGFloat { size.width }
    public var height: CGFloat { size.height }
    public var minX: CGFloat { origin.x }
    public var minY: CGFloat { origin.y }
    public var midX: CGFloat { origin.x + size.width / 2 }
    public var midY: CGFloat { origin.y + size.height / 2 }
    public var maxX: CGFloat { origin.x + size.width }
    public var maxY: CGFloat { origin.y + size.height }
    public var isEmpty: Bool { size.width <= 0 || size.height <= 0 }

    public func insetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        CGRect(x: origin.x + dx, y: origin.y + dy, width: size.width - 2 * dx, height: size.height - 2 * dy)
    }

    public func offsetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        CGRect(x: origin.x + dx, y: origin.y + dy, width: size.width, height: size.height)
    }

    public func contains(_ point: CGPoint) -> Bool {
        point.x >= minX && point.x < maxX && point.y >= minY && point.y < maxY
    }
}

/// UIKit's additions: a table's section and row, or a collection's item
extension IndexPath {
    public init(row: Int, section: Int) {
        self.init(indexes: [section, row])
    }

    public init(item: Int, section: Int) {
        self.init(indexes: [section, item])
    }

    public var section: Int {
        get { self[0] }
        set { self = IndexPath(indexes: [newValue, count > 1 ? self[1] : 0]) }
    }

    public var row: Int {
        get { self[1] }
        set { self = IndexPath(indexes: [count > 0 ? self[0] : 0, newValue]) }
    }

    public var item: Int {
        get { self[1] }
        set { row = newValue }
    }
}
