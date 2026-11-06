/*****************************************************************************
 * VLCiOS6App.swift
 * VLC for iOS 6
 *****************************************************************************
 * Copyright (c) 2026 VideoLAN. All rights reserved.
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import Foundation
import ObjCInterop
import SwiftUI
import UIKit

// VLC for iOS 6: the media in the app's Documents folder (where iTunes file
// sharing puts it), played with MobileVLCKit. Embedded Swift, built with
// Swift-iOS6's toolchain and SwiftUI library, see README.md.

@main
struct VLCiOS6App: App {
    let library = MediaLibrary()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                MediaListView()
            }
            .environmentObject(library)
        }
    }
}

struct MediaFile: Identifiable, Equatable {
    /// The file's path
    let id: String
    let name: String
    let size: String
}

final class MediaLibrary: ObservableObject {
    @Published var files: [MediaFile] = []
    let documentsPath: String
    /// The player on screen, kept alive while it's presented
    private var player: ObjCValue?

    init() {
        // NSDocumentDirectory in NSUserDomainMask
        let urls = NSFileManager.defaultManager().URLsForDirectory(9, inDomains: 1)
        documentsPath = urls.count > 0 ? NSURL(urls.objectAtIndex(0)).path ?? "" : ""
        reload()
    }

    func reload() {
        let manager = NSFileManager.defaultManager()
        guard let names = manager.contentsOfDirectoryAtPath(documentsPath, error: ObjC.nil) else {
            if !files.isEmpty { files = [] }
            return
        }
        var found: [MediaFile] = []
        for index in 0..<names.count {
            guard let name = names.objectAtIndex(index).asString, !name.hasPrefix(".") else { continue }
            let path = documentsPath + "/" + name
            guard let attributes = manager.attributesOfItemAtPath(path, error: ObjC.nil) else { continue }
            if attributes.objectForKey(ObjCValue("NSFileType")).asString == "NSFileTypeDirectory" {
                continue
            }
            let bytes = attributes.objectForKey(ObjCValue("NSFileSize")).asInt64 ?? 0
            found.append(MediaFile(id: path, name: name, size: formatSize(bytes)))
        }
        found.sort { $0.name < $1.name }
        if found != files { files = found }
    }

    func play(_ file: MediaFile) {
        guard let root = UIApplication.sharedApplication().keyWindow?.rootViewController else { return }
        let player = PlayerViewController.make(path: file.id, name: file.name)
        self.player = player
        root.presentModalViewController(UIViewController(player), animated: true)
    }
}

/// "12.3 MB", without floating point formatting (Embedded Swift has none)
func formatSize(_ bytes: Int64) -> String {
    let units = ["B", "KB", "MB", "GB"]
    var value = bytes * 10
    var unit = 0
    while value >= 10240 && unit < units.count - 1 {
        value /= 1024
        unit += 1
    }
    if unit == 0 { return "\(bytes) B" }
    return "\(value / 10).\(value % 10) \(units[unit])"
}

struct MediaListView: View {
    @EnvironmentObject var library: MediaLibrary

    var body: some View {
        List {
            if library.files.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("EMPTY_LIBRARY", comment: ""))
                        .font(.headline)
                    Text(NSLocalizedString("EMPTY_LIBRARY_LONG", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(8)
            }
            ForEach(library.files) { file in
                Button(action: { library.play(file) }) {
                    HStack {
                        Text(file.name)
                        Spacer()
                        Text(file.size)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("SHARED_VLC_IOS_LIBRARY_SHORT", comment: ""))
        .task {
            // Files arrive through iTunes file sharing while the app runs
            while true {
                library.reload()
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    return
                }
            }
        }
    }
}
