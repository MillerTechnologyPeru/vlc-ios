/*****************************************************************************
 * PodcastProgressBar.swift
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
class PodcastProgressBar: UIViewMethods {
    private let trackView = UIView()
    private let fillView = UIView()
    private var fillWidthConstraint: NSLayoutConstraint?

    var progress: CGFloat = 0 {
        didSet {
            updateFillWidth()
        }
    }

    init(frame: CGRect) {
        objcInit("initWithFrame:", frame)
        setup()
    }

    init?(coder: NSCoder) {
        objcInit("initWithCoder:", coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true

        trackView.translatesAutoresizingMaskIntoConstraints = false
        fillView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(trackView)
        trackView.addSubview(fillView)

        NSLayoutConstraint.activate([
            trackView.topAnchor.constraint(equalTo: topAnchor),
            trackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            fillView.topAnchor.constraint(equalTo: trackView.topAnchor),
            fillView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
            fillView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor)
        ])

        let widthConstraint = fillView.widthAnchor.constraint(equalToConstant: 0)
        widthConstraint.isActive = true
        fillWidthConstraint = widthConstraint

        applyTheme()
        NotificationCenter.default.addObserver(self,
                                                selector: ObjC.selector("applyTheme"),
                                                name: .VLCThemeDidChangeNotification,
                                                object: nil)
    }

    @ObjCMethod("layoutSubviews") func layoutSubviews() {
        callSuper("layoutSubviews")
        layer.cornerRadius = bounds.height / 2
        trackView.layer.cornerRadius = layer.cornerRadius
        fillView.layer.cornerRadius = layer.cornerRadius
        updateFillWidth()
    }

    private func updateFillWidth() {
        let clamped = max(0, min(1, progress))
        fillWidthConstraint?.constant = bounds.width * clamped
    }

    @ObjCMethod private func applyTheme() {
        let colors = PresentationTheme.current.colors
        trackView.backgroundColor = colors.separatorColor
        fillView.backgroundColor = colors.orangeUI
    }
}
