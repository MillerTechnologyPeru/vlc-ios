/*****************************************************************************
 * CarPlayMediaLibraryObserver.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2022, 2026 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import Foundation

protocol CPMediaLibraryObserverDelegate: AnyObject {
    func templatesNeedUpdate()
}

@ObjCImplementation(extensions: ["MediaLibraryObserver"])
class CarPlayMediaLibraryObserver: NSObjectMethods {
    init() { objcInit() }

    weak var observerDelegate: CPMediaLibraryObserverDelegate?
}

@ObjCExtension("MediaLibraryObserver")
extension CarPlayMediaLibraryObserver: MediaLibraryObserver {
    @ObjCMethod func observeLibrary() {
        VLCAppCoordinator.sharedInstance().mediaLibraryService.observable.addObserver(self)
    }

    @ObjCMethod func unobserveLibrary() {
        VLCAppCoordinator.sharedInstance().mediaLibraryService.observable.removeObserver(self)
    }

    func medialibrary(_ medialibrary: MediaLibraryService, didAddPlaylists playlists: [VLCMLPlaylist]) {
        observerDelegate?.templatesNeedUpdate()
    }

    func medialibrary(_ medialibrary: MediaLibraryService, didDeletePlaylistsWithIds playlistsIds: [NSNumber]) {
        observerDelegate?.templatesNeedUpdate()
    }
}
