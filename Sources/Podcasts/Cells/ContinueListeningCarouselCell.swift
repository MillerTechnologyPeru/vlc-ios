/*****************************************************************************
 * ContinueListeningCarouselCell.swift
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

@ObjCImplementation
class ContinueListeningCarouselCell: UICollectionViewCellMethods {
    static let reuseIdentifier = "ContinueListeningCarouselCell"

    private let artworkView = PodcastArtworkView()
    private let progressBar = PodcastProgressBar()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredCustomFont(forTextStyle: .footnote).semibolded
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let showNameLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .caption2)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(frame: CGRect) {
        objcInit("initWithFrame:", frame)
        setupUI()
    }

    init?(coder: NSCoder) {
        objcInit("initWithCoder:", coder)
        setupUI()
    }

    private func setupUI() {
        artworkView.addSubview(progressBar)

        contentView.addSubview(artworkView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(showNameLabel)

        NSLayoutConstraint.activate([
            artworkView.topAnchor.constraint(equalTo: contentView.topAnchor),
            artworkView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            artworkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            artworkView.heightAnchor.constraint(equalTo: artworkView.widthAnchor),

            progressBar.leadingAnchor.constraint(equalTo: artworkView.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: artworkView.trailingAnchor),
            progressBar.bottomAnchor.constraint(equalTo: artworkView.bottomAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 4),

            titleLabel.topAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            showNameLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            showNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            showNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])

        applyTheme()
        NotificationCenter.default.addObserver(self,
                                                selector: ObjC.selector("applyTheme"),
                                                name: .VLCThemeDidChangeNotification,
                                                object: nil)
    }

    func configure(episode: PodcastEpisode, show: PodcastShow?) {
        VLCAppCoordinator.sharedInstance().podcastStore.requestArtwork(for: episode)
        if let show = show {
            VLCAppCoordinator.sharedInstance().podcastStore.requestArtwork(for: show)
        }
        artworkView.configure(name: show?.name ?? "",
                              artworkURL: episode.artworkURL ?? show?.artworkURL,
                              cornerRadius: 12)
        progressBar.progress = episode.progressFraction
        titleLabel.text = episode.title
        showNameLabel.text = show?.name
        accessibilityLabel = "\(episode.title), \(show?.name ?? "")"
    }

    @ObjCMethod private func applyTheme() {
        let colors = PresentationTheme.current.colors
        titleLabel.textColor = colors.cellTextColor
        showNameLabel.textColor = colors.cellDetailTextColor
    }

    @ObjCMethod("prepareForReuse") func prepareForReuse() {
        callSuper("prepareForReuse")
        progressBar.progress = 0
    }
}
