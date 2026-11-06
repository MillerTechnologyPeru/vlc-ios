/*****************************************************************************
 * VLCiOS6.swift
 * VLC for iOS 6
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

// What VLC-iOS-Bridging-Header.h gives VLC's Swift in the iOS build: every
// file of the app imports this module implicitly (-import-module VLCiOS6),
// so it re-exports the frameworks and declares VLCKit's, VLCMediaLibraryKit's
// and the app's own Objective-C classes for Embedded Swift.

@_exported import Foundation
@_exported import UIKit
@_exported import VLCKit
@_exported import VLCMediaLibraryKit
