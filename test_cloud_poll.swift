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
let cloudDocs = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
// Try to find a file we can test with, or just monitor the directory
let path = cloudDocs

print("Polling \(path.lastPathComponent) every 1s...")
print("Please trigger a download or change a cloud file now.")

// Loop for 30 seconds
for i in 0..<30 {
    do {
        let items = try fm.contentsOfDirectory(at: path, includingPropertiesForKeys: [
            .ubiquitousItemDownloadingStatusKey,
            .ubiquitousItemIsDownloadingKey
        ], options: [.skipsHiddenFiles])
        
        // Find any file that is NOT current
        let pending = items.filter { url in
            let res = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            return res?.ubiquitousItemDownloadingStatus == .notDownloaded
        }
        
        let downloading = items.filter { url in
            let res = try? url.resourceValues(forKeys: [.ubiquitousItemIsDownloadingKey])
            return res?.ubiquitousItemIsDownloading == true
        }
        
        print("[\(i)] Pending: \(pending.count), Downloading: \(downloading.count)")
        if !downloading.isEmpty {
            print("   -> Downloading: \(downloading.map { $0.lastPathComponent })")
        }
        
        sleep(1)
    } catch {
        print("Error: \(error)")
    }
}
