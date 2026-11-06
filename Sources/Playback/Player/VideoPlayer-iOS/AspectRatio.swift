/*****************************************************************************
 * AspectRatio.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2023 VideoLAN. All rights reserved.
 *
 * Authors: Diogo Simao Marques <dogo@videolabs.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

// Also built with Embedded Swift for iOS 6 (Sources/App/iOS6), which has no
// @objc: there, NSLocalizedString comes from the iOS 6 app. #if can't wrap an
// attribute alone, so the cases are declared for each.
#if !hasFeature(Embedded)
import UIKit

enum AspectRatio: Int, CaseIterable {
    case Default = 0
    case fillToScreen
    case fourToThree
    case fiveToFour
    case sixteenToNine
    case sixteenToTen
    case twentyOneToOne
    case thirtyFiveToOne
    case thirtyNineToOne
}
#else
enum AspectRatio: Int, CaseIterable {
    case Default = 0
    case fillToScreen
    case fourToThree
    case fiveToFour
    case sixteenToNine
    case sixteenToTen
    case twentyOneToOne
    case thirtyFiveToOne
    case thirtyNineToOne
}
#endif

extension AspectRatio {
    var stringToDisplay: String {
        switch self {
        case .Default:
            return NSLocalizedString("DEFAULT", comment: "")
        case .fillToScreen:
            return NSLocalizedString("FILL_TO_SCREEN", comment: "")
        case .fourToThree:
            return "4:3"
        case .fiveToFour:
            return "5:4"
        case .sixteenToNine:
            return "16:9"
        case .sixteenToTen:
            return "16:10"
        case .twentyOneToOne:
            return "2.21:1"
        case .thirtyFiveToOne:
            return "2.35:1"
        case .thirtyNineToOne:
            return "2.39:1"
        }
    }

    var value: String {
        switch self {
        case .twentyOneToOne:
            return "221:100"
        case .thirtyFiveToOne:
            return "235:100"
        case .thirtyNineToOne:
            return "239:100"
        default:
            return stringToDisplay
        }
    }
}

#if !hasFeature(Embedded)
@ObjCImplementation("VLCAspectRatioBridge")
class AspectRatioBridge: NSObjectMethods {
    init() { objcInit() }

    @ObjCMethod class func stringToDisplay(for rawValue: Int) -> String? {
        guard let aspectRatio = AspectRatio(rawValue: rawValue) else {
            return nil
        }

        return aspectRatio.stringToDisplay
    }

    @ObjCMethod class func value(for rawValue: Int) -> String? {
        guard let aspectRatio = AspectRatio(rawValue: rawValue) else {
            return nil
        }

        return aspectRatio.value
    }
}
#endif
