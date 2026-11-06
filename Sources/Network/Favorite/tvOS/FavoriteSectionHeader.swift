/*****************************************************************************
 * FavoriteSectionHeader.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2024 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Eshan Singh <eeeshan789@icloud.com>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import Foundation

@ObjCImplementation
class FavoriteSectionHeader: UICollectionReusableViewMethods {
    static var identifier = "FavoriteSectionHeader"
    static var height: CGFloat = 100
    
    lazy var headerView: FavoriteHeaderContentView = {
        return FavoriteHeaderContentView()
    }()

    
    init(frame: CGRect) {
        objcInit("initWithFrame:", frame)
        setupheaderView()
    }
    
    private func setupheaderView() {
       
      addSubview(headerView)
      headerView.translatesAutoresizingMaskIntoConstraints = false
     
      NSLayoutConstraint.activate([
        headerView.topAnchor.constraint(equalTo: topAnchor),
        headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
        headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
        headerView.bottomAnchor.constraint(equalTo: bottomAnchor)
      ])
    }
}
