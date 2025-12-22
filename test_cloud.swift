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

// Helper to print status
func checkCloudStatus(at path: String) {
    let url = URL(fileURLWithPath: path)
    
    do {
        let values = try url.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .ubiquitousItemIsUploadingKey,
            .ubiquitousItemIsUploadedKey
        ])
        
        print("File: \(url.lastPathComponent)")
        print("  isUbiquitous: \(values.isUbiquitousItem ?? false)")
        
        if let status = values.ubiquitousItemDownloadingStatus {
            print("  DownloadingStatus: \(status.rawValue)")
            switch status {
            case .current: print("    (Current: Local & synced)")
            case .downloaded: print("    (Downloaded: Local)")
            case .notDownloaded: print("    (Not Downloaded: Cloud only)")
            default: print("    (Unknown)")
            }
        } else {
            print("  DownloadingStatus: nil")
        }
        
        // Removed IsDownloaded check as it is unavailable
        print("  IsUploading: \(values.ubiquitousItemIsUploading ?? false)")
        print("  IsUploading: \(values.ubiquitousItemIsUploading ?? false)")
        print("  IsUploaded: \(values.ubiquitousItemIsUploaded ?? false)")
        
    } catch {
        print("Error checking \(path): \(error)")
    }
}

// Check a few paths
// You can pass arguments or hardcode some test paths that might be in iCloud
let args = CommandLine.arguments
if args.count > 1 {
    for i in 1..<args.count {
        checkCloudStatus(at: args[i])
    }
} else {
    // defaults checks - try to find something in iCloud Drive if possible
    let iCloudDrive = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    if let iCloudDrive = iCloudDrive {
        print("Checking iCloud Root: \(iCloudDrive.path)")
        checkCloudStatus(at: iCloudDrive.path)
    } else {
        print("Could not access default iCloud Ubiquity Container. (Sandboxed app might fail without entitlements, but CLI script might work if user has access)")
        // Try standard path
        let standardiCloud = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        print("Checking standard iCloud path: \(standardiCloud.path)")
        checkCloudStatus(at: standardiCloud.path)
    }
}
