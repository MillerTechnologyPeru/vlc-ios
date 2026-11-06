//
//  VLCPCloudCellContentWrapper.swift
//  VLC-iOS
//
//  Created by Eshan Singh on 14/07/24.
//  Copyright © 2024 VideoLAN. All rights reserved.
//

import Foundation
import PCloudSDKSwift

@ObjCImplementation
class VLCPCloudCellContentWrapper: NSObjectMethods {

    let content: Content

    var folderID: NSNumber?
    var fileID: NSNumber?
    var fileSize: NSNumber?
    var parent: NSNumber?
    var name: String?
    var isDirectory: Bool
    var isAudioFile: Bool = false
    var isVideoFile: Bool = false
    var hasThumbnail: Bool = false

    init(content: Content) {
        self.content = content

        if content.isFolder {
            self.folderID = content.folderMetadata?.id as? NSNumber
            self.parent = content.folderMetadata?.parentFolderId as? NSNumber
            self.name = content.folderMetadata?.name
            self.isDirectory = true
        } else {
            self.fileID = content.fileMetadata?.id as? NSNumber
            self.parent = content.fileMetadata?.parentFolderId as? NSNumber
            self.name = content.fileMetadata?.name
            self.fileSize = content.fileMetadata?.size as? NSNumber
            self.isDirectory = false
            self.isAudioFile = content.fileMetadata?.isAudio ?? false
            self.isVideoFile = content.fileMetadata?.isVideo ?? false
            self.hasThumbnail = content.fileMetadata?.hasThumbnail ?? false
        }
        objcInit()
    }
}
