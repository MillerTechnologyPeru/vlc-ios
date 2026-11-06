/*****************************************************************************
 * UIKit+Layout.swift
 * VLC for iOS 6
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

// Layout anchors (iOS 9) and active constraints (iOS 8) on top of iOS 6's
// Auto Layout: an anchor is a view and an attribute, and its constraint
// methods make an NSLayoutConstraint with
// +constraintWithItem:attribute:relatedBy:toItem:attribute:multiplier:constant:.
// iOS 6 has no layout guides either: safeAreaLayoutGuide and
// layoutMarginsGuide are the view itself.

/// NSLayoutAttribute
public enum NSLayoutAttribute {
    public static let left = 1
    public static let right = 2
    public static let top = 3
    public static let bottom = 4
    public static let leading = 5
    public static let trailing = 6
    public static let width = 7
    public static let height = 8
    public static let centerX = 9
    public static let centerY = 10
    public static let lastBaseline = 11
    public static let notAnAttribute = 0
}

/// NSLayoutRelation
public enum NSLayoutRelation {
    public static let lessThanOrEqual = -1
    public static let equal = 0
    public static let greaterThanOrEqual = 1
}

/// What NSLayoutXAxisAnchor, NSLayoutYAxisAnchor and NSLayoutDimension share
public protocol LayoutAnchor {
    var item: ObjCValue { get }
    var attribute: Int { get }
}

extension LayoutAnchor {
    fileprivate func constraint(_ relation: Int, _ other: (any LayoutAnchor)?, multiplier: CGFloat,
                                constant: CGFloat) -> NSLayoutConstraint {
        NSLayoutConstraint.constraintWithItem(item, attribute: attribute, relatedBy: relation,
                                              toItem: other?.item ?? ObjC.nil,
                                              attribute: other?.attribute ?? NSLayoutAttribute.notAnAttribute,
                                              multiplier: multiplier, constant: constant)
    }
}

public struct NSLayoutXAxisAnchor: LayoutAnchor {
    public let item: ObjCValue
    public let attribute: Int

    public func constraint(equalTo anchor: NSLayoutXAxisAnchor, constant: CGFloat = 0) -> NSLayoutConstraint {
        constraint(NSLayoutRelation.equal, anchor, multiplier: 1, constant: constant)
    }

    public func constraint(greaterThanOrEqualTo anchor: NSLayoutXAxisAnchor, constant: CGFloat = 0) -> NSLayoutConstraint {
        constraint(NSLayoutRelation.greaterThanOrEqual, anchor, multiplier: 1, constant: constant)
    }

    public func constraint(lessThanOrEqualTo anchor: NSLayoutXAxisAnchor, constant: CGFloat = 0) -> NSLayoutConstraint {
        constraint(NSLayoutRelation.lessThanOrEqual, anchor, multiplier: 1, constant: constant)
    }
}

public struct NSLayoutYAxisAnchor: LayoutAnchor {
    public let item: ObjCValue
    public let attribute: Int

    public func constraint(equalTo anchor: NSLayoutYAxisAnchor, constant: CGFloat = 0) -> NSLayoutConstraint {
        constraint(NSLayoutRelation.equal, anchor, multiplier: 1, constant: constant)
    }

    public func constraint(greaterThanOrEqualTo anchor: NSLayoutYAxisAnchor, constant: CGFloat = 0) -> NSLayoutConstraint {
        constraint(NSLayoutRelation.greaterThanOrEqual, anchor, multiplier: 1, constant: constant)
    }

    public func constraint(lessThanOrEqualTo anchor: NSLayoutYAxisAnchor, constant: CGFloat = 0) -> NSLayoutConstraint {
        constraint(NSLayoutRelation.lessThanOrEqual, anchor, multiplier: 1, constant: constant)
    }
}

public struct NSLayoutDimension: LayoutAnchor {
    public let item: ObjCValue
    public let attribute: Int

    public func constraint(equalToConstant constant: CGFloat) -> NSLayoutConstraint {
        constraint(NSLayoutRelation.equal, nil, multiplier: 1, constant: constant)
    }

    public func constraint(greaterThanOrEqualToConstant constant: CGFloat) -> NSLayoutConstraint {
        constraint(NSLayoutRelation.greaterThanOrEqual, nil, multiplier: 1, constant: constant)
    }

    public func constraint(lessThanOrEqualToConstant constant: CGFloat) -> NSLayoutConstraint {
        constraint(NSLayoutRelation.lessThanOrEqual, nil, multiplier: 1, constant: constant)
    }

    public func constraint(equalTo anchor: NSLayoutDimension, multiplier: CGFloat = 1,
                           constant: CGFloat = 0) -> NSLayoutConstraint {
        constraint(NSLayoutRelation.equal, anchor, multiplier: multiplier, constant: constant)
    }

    public func constraint(greaterThanOrEqualTo anchor: NSLayoutDimension, multiplier: CGFloat = 1,
                           constant: CGFloat = 0) -> NSLayoutConstraint {
        constraint(NSLayoutRelation.greaterThanOrEqual, anchor, multiplier: multiplier, constant: constant)
    }

    public func constraint(lessThanOrEqualTo anchor: NSLayoutDimension, multiplier: CGFloat = 1,
                           constant: CGFloat = 0) -> NSLayoutConstraint {
        constraint(NSLayoutRelation.lessThanOrEqual, anchor, multiplier: multiplier, constant: constant)
    }
}

extension UIViewMethods {
    public var leadingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: object, attribute: NSLayoutAttribute.leading) }
    public var trailingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: object, attribute: NSLayoutAttribute.trailing) }
    public var leftAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: object, attribute: NSLayoutAttribute.left) }
    public var rightAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: object, attribute: NSLayoutAttribute.right) }
    public var centerXAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: object, attribute: NSLayoutAttribute.centerX) }
    public var topAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: object, attribute: NSLayoutAttribute.top) }
    public var bottomAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: object, attribute: NSLayoutAttribute.bottom) }
    public var centerYAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: object, attribute: NSLayoutAttribute.centerY) }
    public var lastBaselineAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: object, attribute: NSLayoutAttribute.lastBaseline) }
    public var widthAnchor: NSLayoutDimension { NSLayoutDimension(item: object, attribute: NSLayoutAttribute.width) }
    public var heightAnchor: NSLayoutDimension { NSLayoutDimension(item: object, attribute: NSLayoutAttribute.height) }

    /// iOS 6 has no layout guides: the view's own edges
    public var safeAreaLayoutGuide: UIView { UIView(object) }
    /// iOS 6 has no layout guides: the view's own edges
    public var layoutMarginsGuide: UIView { UIView(object) }
}

extension NSLayoutConstraintMethods {
    /// Whether the constraint is installed on its items' closest common
    /// ancestor, which is where iOS 8 activates it
    public var isActive: Bool {
        get { owner != nil }
        nonmutating set {
            if newValue {
                guard owner == nil, let view = commonAncestor() else { return }
                view.addConstraint(self)
            } else {
                owner?.removeConstraint(self)
            }
        }
    }

    private var firstView: UIView? {
        let item = firstItem
        return item.isNil ? nil : UIView(item)
    }

    private var secondView: UIView? {
        let item = secondItem
        return item.isNil ? nil : UIView(item)
    }

    /// The view the constraint is installed on, if any
    private var owner: UIView? {
        var view = commonAncestor()
        while let candidate = view {
            if let constraints = candidate.constraints {
                for index in 0..<constraints.count
                    where constraints.objectAtIndex(index).asObject?.pointer == object.asObject?.pointer {
                    return candidate
                }
            }
            view = candidate.superview
        }
        return nil
    }

    private func commonAncestor() -> UIView? {
        guard let first = firstView else { return nil }
        guard let second = secondView else { return first }
        var ancestor: UIView? = first
        while let candidate = ancestor {
            if second.isDescendantOfView(candidate) { return candidate }
            ancestor = candidate.superview
        }
        return nil
    }
}

extension NSLayoutConstraint {
    /// +activateConstraints: (iOS 8)
    public static func activate(_ constraints: [NSLayoutConstraint]) {
        for constraint in constraints { constraint.isActive = true }
    }

    /// +deactivateConstraints: (iOS 8)
    public static func deactivate(_ constraints: [NSLayoutConstraint]) {
        for constraint in constraints { constraint.isActive = false }
    }
}
