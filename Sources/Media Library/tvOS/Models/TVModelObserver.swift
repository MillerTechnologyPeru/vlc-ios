/*****************************************************************************
 * TVModelObserver.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2023-2026 VideoLAN. All rights reserved.
 *
 * Authors: Eshan Singh <eshansingh.dev # gmail.com>
 *          Felix Paul Kühne <fkuehne # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import Foundation

protocol MediaLibraryDelegate: AnyObject {
    func refreshCollection()
}

@ObjCImplementation(extensions: ["MediaLibraryBaseModelObserver"])
class TVModelObserver: NSObjectMethods {
    weak var observerDelegate: MediaLibraryDelegate?

    var videoModel: VideoModel? = nil
    var audioModel: TrackModel? = nil

    var playlistModel: PlaylistModel? = nil

    init(observerDelegate: MediaLibraryDelegate? = nil, videoModel: VideoModel, audioModel: TrackModel) {
        self.observerDelegate = observerDelegate
        self.videoModel = videoModel
        self.audioModel = audioModel
        objcInit()
    }

    init(observerDelegate: MediaLibraryDelegate, playlistModel: PlaylistModel) {
        self.playlistModel = playlistModel
        self.observerDelegate = observerDelegate
        objcInit()
    }
}

@ObjCExtension("MediaLibraryBaseModelObserver")
extension TVModelObserver: MediaLibraryBaseModelObserver {
    func mediaLibraryBaseModelReloadView() {
        observerDelegate?.refreshCollection()
    }

    @ObjCMethod func observeLibrary() {

        if let video = videoModel {
            video.observable.addObserver(self)
            video.getMedia()
        }
        if let audio = audioModel {
            audio.observable.addObserver(self)
            audio.getMedia()
        }
        if let playlist = playlistModel {
            playlist.observable.addObserver(self)
            playlist.getMedia()
        }

    }

    @ObjCMethod func loadNextVideoPage() {
        videoModel?.getMedia()
    }

    @ObjCMethod func loadNextAudioPage() {
        audioModel?.getMedia()
    }

    @ObjCMethod func unobserveLibrary() {
        if let video = videoModel {
            video.observable.removeObserver(self)
        }
        if let audio = audioModel {
            audio.observable.removeObserver(self)
        }
        if let playlist = playlistModel {
            playlist.observable.removeObserver(self)
        }
    }
}
