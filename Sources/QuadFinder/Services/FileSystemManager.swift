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

@MainActor
class FileSystemManager {
    static let shared = FileSystemManager()
    
    private let fileManager = FileManager.default
    
    func getContents(at path: URL) -> [FileItem] {
        do {
            let resourceKeys: [URLResourceKey] = [
                .isDirectoryKey, 
                .nameKey, 
                .isPackageKey, 
                .contentModificationDateKey, 
                .isSymbolicLinkKey,
                .ubiquitousItemDownloadingStatusKey,
                .ubiquitousItemIsDownloadingKey,
                .fileSizeKey,
                .creationDateKey
            ]
            let contents = try fileManager.contentsOfDirectory(at: path, 
                                                             includingPropertiesForKeys: resourceKeys,
                                                             options: [.skipsHiddenFiles])
            
            return contents.map { url in
                let resources = try? url.resourceValues(forKeys: Set(resourceKeys))
                var isDirectory = resources?.isDirectory ?? false
                let isPackage = resources?.isPackage ?? false
                let isSymbolicLink = resources?.isSymbolicLink ?? false
                let downloadingStatus = resources?.ubiquitousItemDownloadingStatus
                let isDownloading = resources?.ubiquitousItemIsDownloading ?? false
                let dateMod = resources?.contentModificationDate ?? Date.distantPast
                let dateCreate = resources?.creationDate ?? Date.distantPast
                let size = resources?.fileSize.map { Int64($0) }
                
                // If it's a symlink, check if destination is a directory
                if isSymbolicLink {
                    if let destination = try? fileManager.destinationOfSymbolicLink(atPath: url.path) {
                        let destURL: URL
                        if destination.hasPrefix("/") {
                            destURL = URL(fileURLWithPath: destination)
                        } else {
                            destURL = url.deletingLastPathComponent().appendingPathComponent(destination)
                        }
                        
                        var isDir: ObjCBool = false
                        if fileManager.fileExists(atPath: destURL.path, isDirectory: &isDir) {
                            isDirectory = isDir.boolValue
                        }
                    }
                }
                
                return FileItem(
                    name: url.lastPathComponent, 
                    url: url, 
                    isDirectory: isDirectory, 
                    isPackage: isPackage, 
                    isSymbolicLink: isSymbolicLink, 
                    downloadingStatus: downloadingStatus,
                    isDownloading: isDownloading,
                    dateModified: dateMod,
                    dateCreated: dateCreate,
                    size: size
                )
            }.sorted { (lhs, rhs) -> Bool in
                // Treat packages as files for sorting purposes (optional, but standard Finder behavior)
                // Treat Symlinks to folders AS folders for sorting
                let lhsIsFolder = lhs.isDirectory && !lhs.isPackage
                let rhsIsFolder = rhs.isDirectory && !rhs.isPackage
                
                if lhsIsFolder && !rhsIsFolder { return true }
                if !lhsIsFolder && rhsIsFolder { return false }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        } catch {
            print("Error listing files: \(error)")
            return []
        }
    }
    
    nonisolated func search(query: String, at path: URL) async -> [FileItem] {
        var results: [FileItem] = []
        let tempFileManager = FileManager() // Sendable error fix: use local instance
        let enumerator = tempFileManager.enumerator(at: path, 
                                                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                                                options: [.skipsHiddenFiles, .skipsPackageDescendants])
        
        while let url = enumerator?.nextObject() as? URL {
            // Check for cancellation periodically if this was a heavy loop, 
            // but for now simple check is okay.
            if Task.isCancelled { return [] }
            
            if url.lastPathComponent.localizedCaseInsensitiveContains(query) {
                let resources = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .contentModificationDateKey, .creationDateKey, .fileSizeKey, .isSymbolicLinkKey, .ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey])
                var isDirectory = resources?.isDirectory ?? false
                let isPackage = resources?.isPackage ?? false
                let isSymbolicLink = resources?.isSymbolicLink ?? false
                let downloadingStatus = resources?.ubiquitousItemDownloadingStatus
                let isDownloading = resources?.ubiquitousItemIsDownloading ?? false
                let dateMod = resources?.contentModificationDate ?? Date.distantPast
                let dateCreate = resources?.creationDate ?? Date.distantPast
                let size = resources?.fileSize.map { Int64($0) }
                
                if isSymbolicLink {
                    // Start of manual symlink resolution block
                    // Note: In search we might skip deep resolution for perf, but consistent behavior is better.
                    // We need a local fileManager instance since we are in nonisolated async
                    let fm = FileManager.default 
                    if let destination = try? fm.destinationOfSymbolicLink(atPath: url.path) {
                         let destURL: URL
                         if destination.hasPrefix("/") {
                             destURL = URL(fileURLWithPath: destination)
                         } else {
                             destURL = url.deletingLastPathComponent().appendingPathComponent(destination)
                         }
                         
                         var isDir: ObjCBool = false
                         if fm.fileExists(atPath: destURL.path, isDirectory: &isDir) {
                             isDirectory = isDir.boolValue
                         }
                    }
                }
                
                results.append(FileItem(
                    name: url.lastPathComponent, 
                    url: url, 
                    isDirectory: isDirectory, 
                    isPackage: isPackage, 
                    isSymbolicLink: isSymbolicLink, 
                    downloadingStatus: downloadingStatus,
                    isDownloading: isDownloading,
                    dateModified: dateMod,
                    dateCreated: dateCreate,
                    size: size
                ))
            }
        }
        
        return results
    }

    func rename(item: FileItem, to newName: String) throws {
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)
        try fileManager.moveItem(at: item.url, to: newURL)
    }
    
    func download(_ item: FileItem) throws {
        try fileManager.startDownloadingUbiquitousItem(at: item.url)
    }
    
    func evict(_ item: FileItem) throws {
        try fileManager.evictUbiquitousItem(at: item.url)
    }
}
