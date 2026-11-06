/*****************************************************************************
 * PodcastsOnAirBridge.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Diogo Simao Marques <dogo@videolabs.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import UIKit

extension Notification.Name {
    static let VLCPodcastsContentDidChange = Notification.Name("VLCPodcastsContentDidChange")
    static let VLCPodcastsRefreshDidEnd = Notification.Name("VLCPodcastsRefreshDidEnd")
    static let VLCPodcastsCachingDidEnd = Notification.Name("VLCPodcastsCachingDidEnd")
}

extension NSNotification {
    static let VLCPodcastsContentDidChange = Notification.Name.VLCPodcastsContentDidChange
    static let VLCPodcastsRefreshDidEnd = Notification.Name.VLCPodcastsRefreshDidEnd
    static let VLCPodcastsCachingDidEnd = Notification.Name.VLCPodcastsCachingDidEnd
}

@ObjCImplementation
final class PodcastResumeItem: NSObjectMethods {
    let episodeId: String
    let showId: String
    let title: String
    let artworkURL: URL?
    let progress: CGFloat
    let lastPlayedDate: Date

    init(episode: PodcastEpisode, artworkURL: URL?, lastPlayedDate: Date) {
        self.episodeId = episode.id
        self.showId = episode.showId
        self.title = episode.title
        self.artworkURL = artworkURL
        self.progress = episode.progressFraction
        self.lastPlayedDate = lastPlayedDate
        objcInit("init")
    }
}

extension VLCOnAirRailItem {
    convenience init(show: PodcastShow) {
        self.init(name: show.name, artworkURL: show.artworkURL)
        subtitle = String(format: NSLocalizedString("PODCAST_EPISODE_COUNT", comment: ""), show.episodeCount)
    }
}

@ObjCImplementation
final class PodcastsOnAirBridge: NSObjectMethods {
    init() { objcInit() }

    private static var store: PodcastStore {
        return VLCAppCoordinator.sharedInstance().podcastStore
    }

    static var numberOfShows: Int {
        return store.shows.count
    }

    static var resumeEpisode: PodcastResumeItem? {
        guard let episode = store.resumeEpisode, let lastPlayedDate = episode.lastPlayedDate else {
            return nil
        }
        let show = store.show(withId: episode.showId)
        return PodcastResumeItem(episode: episode,
                                 artworkURL: episode.artworkURL ?? show?.artworkURL,
                                 lastPlayedDate: lastPlayedDate)
    }

    @ObjCMethod static func playResumeEpisode(_ item: PodcastResumeItem) {
        store.playEpisode(episodeId: item.episodeId, showId: item.showId)
    }

    @ObjCMethod static func refreshAllSubscriptions() -> Bool {
        return store.refreshAllSubscriptions()
    }

    static var automaticDownloadsEnabled: Bool {
        return store.automaticDownloadsEnabled
    }

    @ObjCMethod static func cacheNewEpisodes() -> Bool {
        return store.cacheNewEpisodes()
    }

    @ObjCMethod static func interruptCaching() {
        store.interruptCaching()
    }

    static var showRailItems: [VLCOnAirRailItem] {
        let shows = store.shows
        shows.forEach { store.requestArtwork(for: $0) }
        return shows.map { VLCOnAirRailItem(show: $0) }
    }

    @ObjCMethod static func makePodcastsViewController() -> UIViewController {
        return PodcastsViewController()
    }

    @ObjCMethod static func presentAddSubscriptionAlert(from viewController: UIViewController) {
        viewController.presentAddSubscriptionAlert { feed in
            let podcastsViewController = PodcastsViewController()
            viewController.navigationController?.pushViewController(podcastsViewController, animated: true)
            podcastsViewController.subscribe(to: [feed])
        }
    }

    @ObjCMethod static func makeDirectoryViewController() -> UIViewController {
        return PodcastDirectoryViewController()
    }

    @ObjCMethod static func makeShowDetailViewController(forShowAt index: Int) -> UIViewController? {
        let shows = store.shows
        guard shows.indices.contains(index) else {
            return nil
        }
        return PodcastShowDetailViewController(show: shows[index])
    }
}
