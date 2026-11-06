/*****************************************************************************
 * VLCAccessibilityIdentifier.swift
 *
 * Copyright © 2018 VLC authors and VideoLAN
 * Copyright © 2018 Videolabs
 *
 * Authors: Soomin Lee <bubu@mikan.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import Foundation

@ObjCImplementation
class VLCAccessibilityIdentifier: NSObjectMethods {
    init() { objcInit() }

    static let video = "video"
    static let audio = "audio"
    static let songs = "songs"
    static let artists = "artists"
    static let albums = "albums"
    static let genres = "genres"
    static let mediaCell = "mediaCell"
    static let mediaMenu = "mediaMenu"
    static let select = "select"
    static let localNetwork = "localNetwork"
    static let onAir = "onAir"
    static let onAirRadio = "onAirRadio"
    static let onAirPodcasts = "onAirPodcasts"
    static let railItem = "railItem"
    static let radioCountry = "radioCountry"
    static let radioAllCountries = "radioAllCountries"
    static let playlist = "playlist"
    static let podcasts = "podcasts"
    static let podcastAdd = "podcastAdd"
    static let podcastDirectory = "podcastDirectory"
    static let podcastEpisode = "podcastEpisode"
    static let podcastLanguage = "podcastLanguage"
    static let settings = "settings"
    static let openSettings = "openSettings"
    static let addServer = "addServer"
    static let local = "local"
    static let photos = "photos"
    static let cloud = "cloud"
    static let stream = "stream"
    static let downloads = "downloads"
    static let favorite = "favorite"
    static let done = "done"
    static let contact = "contact"
    static let about = "about"
    static let playPause = "playPause"
    static let videoPlayerScrubBar = "videoPlayerScrubBar"
    static let moreOptions = "moreOptions"
    static let closePlayback = "closePlayback"
}
