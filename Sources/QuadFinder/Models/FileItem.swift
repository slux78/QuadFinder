/*
    QuadFinder
    Copyright (C) 2025 QuadFinder

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

import Foundation
import SwiftUI

struct FileItem: Identifiable, Hashable {
    var id: URL { url }
    let name: String
    let url: URL
    let isDirectory: Bool
    let isPackage: Bool
    let isSymbolicLink: Bool
    let downloadingStatus: URLUbiquitousItemDownloadingStatus?
    let isDownloading: Bool
    let dateModified: Date
    let dateCreated: Date
    let size: Int64?
    
    // Helper to get system icon
    var icon: Image {
        let nsImage = NSWorkspace.shared.icon(forFile: url.path)
        return Image(nsImage: nsImage)
    }
    
    var kind: String {
        if isSymbolicLink { return "Alias" }
        if isPackage { return "Application" }
        if isDirectory { return "Folder" }
        return url.pathExtension.isEmpty ? "File" : url.pathExtension.uppercased()
    }
    
    var isCloud: Bool {
        // Only consider it "Cloud" in UI if it's NOT local (needs download) or currently downloading.
        // Fully local/synced files (.current/.downloaded) should look normal.
        needsDownload || isDownloading
    }
    
    var needsDownload: Bool {
        downloadingStatus == .notDownloaded
    }
}
