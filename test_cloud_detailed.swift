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

let fm = FileManager.default
let home = fm.homeDirectoryForCurrentUser
// Check potentially multiple cloud providers
var pathsToCheck: [URL] = []

// 1. iCloud Drive
let iCloudDrive = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
pathsToCheck.append(iCloudDrive)

// 2. CloudStorage (Google Drive, OneDrive, etc. on modern macOS)
let cloudStorage = home.appendingPathComponent("Library/CloudStorage")
if let providers = try? fm.contentsOfDirectory(at: cloudStorage, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
    pathsToCheck.append(contentsOf: providers)
}

print("Checking Cloud Paths: \(pathsToCheck.map { $0.path })")

for path in pathsToCheck {
    print("\n--- Checking Provider: \(path.lastPathComponent) ---")
    do {
        let items = try fm.contentsOfDirectory(at: path, includingPropertiesForKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
        .ubiquitousItemIsDownloadingKey,
        .ubiquitousItemIsUploadedKey,
        .ubiquitousItemIsUploadingKey
    ], options: [.skipsHiddenFiles])

    print("Found \(items.count) items.")
    for item in items.prefix(10) {
        let values = try item.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .ubiquitousItemIsDownloadingKey,
            .ubiquitousItemIsUploadedKey,
            .ubiquitousItemIsUploadingKey
        ])
        
        print("\nFile: \(item.lastPathComponent)")
        print("  isUbiquitous: \(values.isUbiquitousItem ?? false)")
        if let status = values.ubiquitousItemDownloadingStatus {
             switch status {
             case .current: print("  Status: .current (Local & Synced)")
             case .downloaded: print("  Status: .downloaded (Local)")
             case .notDownloaded: print("  Status: .notDownloaded (Cloud Only)")
             default: print("  Status: \(status.rawValue)")
             }
        } else {
            print("  Status: nil")
        }
        
        print("  IsDownloading: \(values.ubiquitousItemIsDownloading ?? false)")
        print("  IsUploaded: \(values.ubiquitousItemIsUploaded ?? false)")
        print("  IsUploading: \(values.ubiquitousItemIsUploading ?? false)")
        print("  IsUploading: \(values.ubiquitousItemIsUploading ?? false)")
    }
} catch {
    } catch {
        print("Error checking \(path.lastPathComponent): \(error)")
    }
}
