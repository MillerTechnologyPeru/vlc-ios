/*****************************************************************************
 * VideoModel.swift
 *
 * Copyright © 2018 VLC authors and VideoLAN
 * Copyright © 2018 Videolabs
 *
 * Authors: Soomin Lee <bubu@mikan.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

@ObjCImplementation
class VideoModel: NSObjectMethods, MediaModel {
    typealias MLType = VLCMLMedia

    var sortModel = SortModel([.alpha, .duration, .insertionDate, .releaseDate, .fileSize, .lastPlaybackDate, .playCount])

    var observable = VLCObservable<MediaLibraryBaseModelObserver>()

    var fileArrayLock = NSRecursiveLock()
    var files = [VLCMLMedia]()

#if !os(tvOS)
    var cellType: BaseCollectionViewCell.Type {
        return UserDefaults.standard.bool(forKey: "\(kVLCVideoLibraryGridLayout)\(name)") ? MovieCollectionViewCell.self : MediaCollectionViewCell.self
    }
#endif

    var medialibrary: MediaLibraryService

    var name: String = "ALL_VIDEOS"

    var indicatorName: String = NSLocalizedString("ALL_VIDEOS", comment: "")

    var currentPage = 0
    var hasMorePages = true
    var isLoading = false

    init(medialibrary: MediaLibraryService) {
        self.medialibrary = medialibrary
        objcInit("init")
        medialibrary.observable.addObserver(self)
    }

    func fetchPage(offset: Int, limit: Int) -> [VLCMLMedia] {
        return medialibrary.media(ofType: .video,
                                  sortingCriteria: sortModel.currentSort,
                                  desc: sortModel.desc,
                                  items: UInt32(limit),
                                  offset: UInt32(offset))
    }

    @ObjCMethod func getMedia(at index: Int) -> VLCMLMedia? {
        fileArrayLock.lock()
        defer { fileArrayLock.unlock() }
        guard index >= 0, index < files.count else { return nil }
        return files[index]
    }
}

// MARK: - MediaLibraryObserver

extension VideoModel: MediaLibraryObserver {
    func medialibrary(_ medialibrary: MediaLibraryService, didAddVideos videos: [VLCMLMedia]) {
        defer {
            fileArrayLock.unlock()
        }
        fileArrayLock.lock()
        videos.forEach({ append($0) })
        observable.notifyObservers {
            $0.mediaLibraryBaseModelReloadView()
        }
    }

    func medialibrary(_ medialibrary: MediaLibraryService, didModifyVideos videos: [VLCMLMedia]) {
        if !videos.isEmpty {
            defer {
                fileArrayLock.unlock()
            }
            fileArrayLock.lock()
            files = swapModels(with: videos)
            observable.notifyObservers {
                $0.mediaLibraryBaseModelReloadView()
            }
        }
    }

    func medialibrary(_ medialibrary: MediaLibraryService, didDeleteMediaWithIds ids: [NSNumber]) {
        defer {
            fileArrayLock.unlock()
        }
        fileArrayLock.lock()
        files = files.filter() {
            for id in ids where $0.identifier() == id.int64Value {
                return false
            }
            return true
        }
        observable.notifyObservers {
            $0.mediaLibraryBaseModelReloadView()
        }
    }

    // MARK: - Thumbnail

    func medialibrary(_ medialibrary: MediaLibraryService,
                      thumbnailReady media: VLCMLMedia,
                      type: VLCMLThumbnailSizeType, success: Bool) {
        guard success else {
            return
        }
        defer {
            fileArrayLock.unlock()
        }
        fileArrayLock.lock()
        files = swapModels(with: [media])
        observable.notifyObservers {
            $0.mediaLibraryBaseModelReloadView()
        }
    }
}
