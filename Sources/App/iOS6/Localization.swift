/*****************************************************************************
 * Localization.swift
 * VLC for iOS 6
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import Foundation

/// Foundation's NSLocalizedString is a macro Embedded Swift doesn't get.
/// This one reads the same Localizable.strings files, from the app bundle, so
/// shared VLC code (AspectRatio) and the iOS 6 screens use VLC's strings.
func NSLocalizedString(_ key: String, comment: String) -> String {
    NSBundle.mainBundle().localizedStringForKey(key, value: nil, table: nil)
}
