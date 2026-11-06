/*****************************************************************************
 * LibraryTabSearchDataSource.swift
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

// MARK: - LibrarySearchScope

enum LibrarySearchScope {
    case video
    case audio
}

// MARK: - LibrarySearchSection

struct LibrarySearchSection {
    let title: String
    let items: [VLCMLObject]
    var mediaGroupNames = [VLCMLIdentifier: String]()
}

// MARK: - LibraryTabSearchDataSourceDelegate

protocol LibraryTabSearchDataSourceDelegate: AnyObject {
    func libraryTabSearchDataSource(_ dataSource: LibraryTabSearchDataSource,
                                    didSelect item: VLCMLObject,
                                    in section: LibrarySearchSection)
    func libraryTabSearchDataSourceWillBeginDragging(_ dataSource: LibraryTabSearchDataSource)
}

// MARK: - LibraryTabSearchDataSource

@ObjCImplementation(protocols: ["UICollectionViewDataSource", "UICollectionViewDelegateFlowLayout"], extensions: ["UICollectionViewDataSource", "UICollectionViewDelegateFlowLayout"])
class LibraryTabSearchDataSource: NSObjectMethods {
    // MARK: Properties

    let scope: LibrarySearchScope
    weak var delegate: LibraryTabSearchDataSourceDelegate?

    private(set) var sections = [LibrarySearchSection]()
    private(set) var searchString: String = ""

    var isEmpty: Bool {
        return sections.isEmpty
    }

    var hasSearchablePattern: Bool {
        return !LibraryTabSearchDataSource.pattern(from: searchString).isEmpty
    }

    private let mediaLibraryService: MediaLibraryService
    private let searchQueue = DispatchQueue(label: "org.videolan.vlc-ios.library-tab-search", qos: .userInitiated)
    private let searchGenerationLock = NSLock()
    private var searchGeneration: Int = 0
    private var cachedCellSize: CGSize = .zero
    private var cachedCellWidth: CGFloat = 0

    private let sectionHeaderHeight: CGFloat = 40.0
    private let searchDelay: TimeInterval = 0.25

    private var medialib: VLCMediaLibrary {
        return mediaLibraryService.medialib
    }

    // MARK: Init

    init(scope: LibrarySearchScope, mediaLibraryService: MediaLibraryService) {
        self.scope = scope
        self.mediaLibraryService = mediaLibraryService
        objcInit("init")
    }

    // MARK: Public methods

    func reset() {
        _ = nextSearchGeneration()
        searchString = ""
        sections = []
    }

    func search(for searchString: String, completion: @escaping () -> Void) {
        self.searchString = searchString
        let generation = nextSearchGeneration()

        guard hasSearchablePattern else {
            sections = []
            completion()
            return
        }

        let pattern = LibraryTabSearchDataSource.pattern(from: searchString)
        searchQueue.asyncAfter(deadline: .now() + searchDelay) { [weak self] in
            // A newer search was requested while this one was queued, skip the queries
            guard let self = self, self.isCurrentSearch(generation) else { return }

            let sections = self.searchSections(for: pattern).filter { !$0.items.isEmpty }

            DispatchQueue.main.async {
                guard self.isCurrentSearch(generation) else {
                    return
                }
                self.sections = sections
                completion()
            }
        }
    }
}

// MARK: - Search generation

private extension LibraryTabSearchDataSource {
    func nextSearchGeneration() -> Int {
        searchGenerationLock.lock()
        defer { searchGenerationLock.unlock() }
        searchGeneration += 1
        return searchGeneration
    }

    func isCurrentSearch(_ generation: Int) -> Bool {
        searchGenerationLock.lock()
        defer { searchGenerationLock.unlock() }
        return generation == searchGeneration
    }
}

// MARK: - Library content

private extension LibraryTabSearchDataSource {
    static func pattern(from searchString: String) -> String {
        return searchString.trimmingCharacters(in: .whitespaces)
    }

    static var isGroupingDisabled: Bool {
        return UserDefaults.standard.bool(forKey: kVLCSettingsDisableGrouping)
    }

    static func isDisplayable(_ mediaGroup: VLCMLMediaGroup) -> Bool {
        return mediaGroup.nbVideo() > 0 && (mediaGroup.nbTotalMedia() > 1 || mediaGroup.userInteracted())
    }

    func searchSections(for pattern: String) -> [LibrarySearchSection] {
        switch scope {
        case .video:
            var videos = LibrarySearchSection(title: NSLocalizedString("VIDEOS", comment: ""),
                                              items: medialib.searchVideo(pattern, sort: .alpha, desc: false) ?? [])
            guard !LibraryTabSearchDataSource.isGroupingDisabled else {
                return [videos]
            }

            videos.mediaGroupNames = mediaGroupNames(of: videos.items)
            let mediaGroups = medialib.searchMediaGroups(withPattern: pattern, sort: .alpha, desc: false)?
                .filter { LibraryTabSearchDataSource.isDisplayable($0) } ?? []
            return [LibrarySearchSection(title: NSLocalizedString("VIDEO_GROUPS", comment: ""), items: mediaGroups),
                    videos]
        case .audio:
            let hideFeatArtists = UserDefaults.standard.bool(forKey: kVLCAudioLibraryHideFeatArtists)
            let artists = medialib.searchArtists(byName: pattern, all: !hideFeatArtists, sort: .alpha, desc: false)?
                .filter {
                    let isGeneratedArtist = $0.identifier() == UnknownArtistID || $0.identifier() == VariousArtistID
                    return !isGeneratedArtist || $0.tracksCount() > 0
                } ?? []

            return [
                LibrarySearchSection(title: NSLocalizedString("ARTISTS", comment: ""),
                                     items: artists),
                LibrarySearchSection(title: NSLocalizedString("ALBUMS", comment: ""),
                                     items: medialib.searchAlbums(byPattern: pattern, sort: .alpha, desc: false) ?? []),
                LibrarySearchSection(title: NSLocalizedString("SONGS", comment: ""),
                                     items: medialib.searchAudio(pattern, sort: .alpha, desc: false) ?? []),
                LibrarySearchSection(title: NSLocalizedString("GENRES", comment: ""),
                                     items: medialib.searchGenre(byName: pattern, sort: .alpha, desc: false) ?? [])
            ]
        }
    }

    func mediaGroupNames(of items: [VLCMLObject]) -> [VLCMLIdentifier: String] {
        let groupIdentifiers = Set(items.compactMap { ($0 as? VLCMLMedia)?.groupIdentifier() })
        var mediaGroupNames = [VLCMLIdentifier: String]()
        for groupIdentifier in groupIdentifiers {
            guard let mediaGroup = medialib.mediaGroup(withIdentifier: groupIdentifier),
                  LibraryTabSearchDataSource.isDisplayable(mediaGroup) else {
                continue
            }
            mediaGroupNames[groupIdentifier] = mediaGroup.name()
        }
        return mediaGroupNames
    }
}

// MARK: - UICollectionViewDataSource

@ObjCExtension("UICollectionViewDataSource")
extension LibraryTabSearchDataSource {
    @ObjCMethod("numberOfSectionsInCollectionView:") func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    @ObjCMethod("collectionView:numberOfItemsInSection:") func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections.objectAtIndex(index: section)?.items.count ?? 0
    }

    @ObjCMethod("collectionView:cellForItemAtIndexPath:") func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaCollectionViewCell.defaultReuseIdentifier,
                                                            for: indexPath) as? MediaCollectionViewCell else {
            assertionFailure("LibraryTabSearchDataSource: MediaCollectionViewCell is not registered.")
            return UICollectionViewCell()
        }

        guard let section = sections.objectAtIndex(index: indexPath.section),
              let item = section.items.objectAtIndex(index: indexPath.row) else {
            return cell
        }

        if let mediaGroup = item as? VLCMLMediaGroup {
            mediaGroup.media(of: .video, sort: .default, desc: false, items: 4, offset: 0)?.forEach {
                mediaLibraryService.requestThumbnail(for: $0)
            }
        } else if let media = item as? VLCMLMedia, media.type() == .video {
            mediaLibraryService.requestThumbnail(for: media)
        }

        cell.isEditing = false
        cell.media = item
        if let media = item as? VLCMLMedia, let mediaGroupName = section.mediaGroupNames[media.groupIdentifier()] {
            cell.showMediaGroup(named: mediaGroupName)
        }
        cell.isAccessibilityElement = true
        cell.accessibilityIdentifier = VLCAccessibilityIdentifier.mediaCell
        cell.disableScrollView()

        return cell
    }

    @ObjCMethod("collectionView:viewForSupplementaryElementOfKind:atIndexPath:") func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                           withReuseIdentifier: TrackSectionHeader.headerID,
                                                                           for: indexPath) as? TrackSectionHeader else {
            return UICollectionReusableView()
        }

        header.update(sectionTitle: sections.objectAtIndex(index: indexPath.section)?.title ?? "")
        return header
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

@ObjCExtension("UICollectionViewDelegateFlowLayout")
extension LibraryTabSearchDataSource {
    @ObjCMethod("collectionView:didSelectItemAtIndexPath:") func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let section = sections.objectAtIndex(index: indexPath.section),
              let item = section.items.objectAtIndex(index: indexPath.row) else {
            return
        }

        delegate?.libraryTabSearchDataSource(self, didSelect: item, in: section)
    }

    @ObjCMethod("scrollViewWillBeginDragging:") func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        delegate?.libraryTabSearchDataSourceWillBeginDragging(self)
    }

    @ObjCMethod("collectionView:layout:sizeForItemAtIndexPath:") func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.safeAreaLayoutGuide.layoutFrame.width
        if cachedCellSize == .zero || cachedCellWidth != width {
            let safeAreaInsets = collectionView.window?.safeAreaInsets ?? collectionView.safeAreaInsets
            cachedCellSize = MediaCollectionViewCell.cellSizeForWidth(width, safeAreaInsets: safeAreaInsets)
            cachedCellWidth = width
        }
        return cachedCellSize
    }

    @ObjCMethod("collectionView:layout:referenceSizeForHeaderInSection:") func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.safeAreaLayoutGuide.layoutFrame.width, height: sectionHeaderHeight)
    }

    @ObjCMethod("collectionView:layout:referenceSizeForFooterInSection:") func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForFooterInSection section: Int) -> CGSize {
        return .zero
    }

    @ObjCMethod("collectionView:layout:insetForSectionAtIndex:") func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        let padding = MediaCollectionViewCell.edgePadding
        return UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
    }

    @ObjCMethod("collectionView:layout:minimumLineSpacingForSectionAtIndex:") func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return MediaCollectionViewCell.edgePadding
    }

    @ObjCMethod("collectionView:layout:minimumInteritemSpacingForSectionAtIndex:") func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return MediaCollectionViewCell.interItemPadding
    }
}
