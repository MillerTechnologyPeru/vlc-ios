/*****************************************************************************
 * TrackSeciton Header.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Timmy Nguyen <timmypass21 # gmail.com.>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import UIKit

@ObjCImplementation
class TrackSectionHeader: UICollectionReusableViewMethods {

    static var headerID = "trackSectionHeaderID"

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = PresentationTheme.current.colors.orangeUI
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var dividerView: UIView = {
        let dividerView = UIView(frame: .zero)
        dividerView.backgroundColor = PresentationTheme.current.colors.separatorColor
        dividerView.translatesAutoresizingMaskIntoConstraints = false
        return dividerView
    }()

    init(frame: CGRect) {
        objcInit("initWithFrame:", frame)

        addSubview(titleLabel)
        addSubview(dividerView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),

            dividerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dividerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dividerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            dividerView.heightAnchor.constraint(equalToConstant: 1)
        ])

        NotificationCenter.default.addObserver(self, selector: ObjC.selector("updateTheme"), name: .VLCThemeDidChangeNotification, object: nil)

        updateTheme()
    }


    func update(sectionTitle: String) {
        titleLabel.text = sectionTitle
    }

    @ObjCMethod private func updateTheme() {
        backgroundColor = PresentationTheme.current.colors.background
        dividerView.backgroundColor = PresentationTheme.current.colors.separatorColor
    }
}

public enum SectionType: Int {
    case special = 0
    case latin = 1
    case nonlatin = 2
}
