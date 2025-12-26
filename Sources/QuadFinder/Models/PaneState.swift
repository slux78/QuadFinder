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

import SwiftUI
import Combine

@MainActor
class PaneState: ObservableObject, Identifiable {
    let id = UUID()
    @Published var currentPath: URL
    @Published var items: [FileItem] = []
    
    // Notification for file system updates
    // Moved to global extension
    @Published var selectedItems: Set<URL> = []
    @Published var preservedSelection: Set<URL> = [] // Stable selection before range ops
    @Published var lastSelectedId: URL? = nil // Anchor for range selection
    @Published var renamingItemId: URL? = nil
    
    // Navigation History
    @Published var backStack: [URL] = []
    @Published var forwardStack: [URL] = []
    
    // Search State
    @Published var isSearching: Bool = false
    @Published var searchQuery: String = ""
    @Published var searchResults: [FileItem] = []
    
    // UI State
    @Published var isActive: Bool = false
    @Published var infoItem: FileItem? = nil
    @Published var customTitle: String? = nil
    
    // Sorting State
    enum SortOption { case name, kind, date, size }
    enum SortOrder { case ascending, descending }
    @Published var sortOption: SortOption = .name
    @Published var sortOrder: SortOrder = .ascending
    
    // Computed property for sorted items
    var sortedItems: [FileItem] {
        let list = isSearching && !searchQuery.isEmpty ? searchResults : items
        return list.sorted { lhs, rhs in
            // Always put folders first (and not packages)
            let lhsIsFolder = lhs.isDirectory && !lhs.isPackage
            let rhsIsFolder = rhs.isDirectory && !rhs.isPackage
            
            if lhsIsFolder != rhsIsFolder {
                return lhsIsFolder
            }
            
            // Standard sort
            switch sortOption {
            case .name:
                return sortOrder == .ascending 
                    ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                    : lhs.name.localizedStandardCompare(rhs.name) == .orderedDescending
            case .kind:
                // Sort by kind, then name
                if lhs.kind != rhs.kind {
                    return sortOrder == .ascending 
                        ? lhs.kind < rhs.kind 
                        : lhs.kind > rhs.kind
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .size:
                // Sort by size (treat nil as 0), then name
                let lhsSize = lhs.size ?? 0
                let rhsSize = rhs.size ?? 0
                if lhsSize != rhsSize {
                     return sortOrder == .ascending 
                        ? lhsSize < rhsSize 
                        : lhsSize > rhsSize
                }
                 return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .date:
                // Sort by date, then name
                if lhs.dateModified != rhs.dateModified {
                    return sortOrder == .ascending
                        ? lhs.dateModified < rhs.dateModified
                        : lhs.dateModified > rhs.dateModified
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }

    init(startPath: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.currentPath = startPath
        startMonitoring()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleFileSystemUpdate(_:)), name: .fileSystemDidUpdateNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleFileSystemUpdate(_ notification: Notification) {
        guard let changedUrls = notification.userInfo?["urls"] as? [URL] else { return }
        
        // Check if any changed URL affects this pane
        let shouldReload = changedUrls.contains { url in
            // If the changed file is IN the current directory
            let parent = url.deletingLastPathComponent()
            if parent.path == currentPath.path { return true }
            
            // Or if the current directory ITSELF changed (renamed/deleted)
            if url.path == currentPath.path { return true }
            
            return false
        }
        
        if shouldReload {
            print("PaneState: Notification received, reloading \(currentPath.path)")
            Task { @MainActor in loadContents() }
        }
    }
    
    func loadContents() {
        items = FileSystemManager.shared.getContents(at: currentPath)
        // Keep selection if items still exist
        selectedItems = selectedItems.filter { id in items.contains(where: { $0.id == id }) }
        preservedSelection = preservedSelection.filter { id in items.contains(where: { $0.id == id }) }
        
        // Verify lastSelectedId still exists
        // Verify lastSelectedId still exists
        if let last = lastSelectedId, !items.contains(where: { $0.id == last }) {
            print("SelectionDebug: lost anchor \(last.path) during reload")
            lastSelectedId = nil
        }
        updatePollingStatus()
    }
    
    func performSearch() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        // Run on background thread ideally, but for now simple
        Task {
            let results = await FileSystemManager.shared.search(query: searchQuery, at: currentPath)
            await MainActor.run {
                self.searchResults = results
            }
        }
    }
    
    func navigateTo(_ url: URL) {
        // Resolve symlinks before navigation to ensure contents functions work
        var targetURL = url
        // Basic check if it is a symlink
        if let resources = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]),
           resources.isSymbolicLink == true {
             // It's a symlink, resolve it
             if let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: url.path) {
                 if destination.hasPrefix("/") {
                     targetURL = URL(fileURLWithPath: destination)
                 } else {
                     targetURL = url.deletingLastPathComponent().appendingPathComponent(destination)
                 }
                 // Normalize path (remove ../ etc)
                 targetURL = targetURL.standardized
             }
        }
    
        if targetURL.path != currentPath.path { // Compare paths to avoid re-nav to same resolved dir
            backStack.append(currentPath)
            forwardStack.removeAll()
            currentPath = targetURL
            isSearching = false // Exit search on nav
            searchQuery = ""
            loadContents()
            startMonitoring()
        }
    }
    
    func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(currentPath)
        currentPath = previous
        isSearching = false
        loadContents()
    }
    
    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(currentPath)
        currentPath = next
        isSearching = false
        loadContents()
    }
    
    func goUp() {
        let parent = currentPath.deletingLastPathComponent()
        navigateTo(parent)
    }
    
    func startRenaming(_ item: FileItem) {
        renamingItemId = item.id
    }
    
    func renameItem(_ item: FileItem, to newName: String, undoManager: UndoManager? = nil) {
        guard !newName.isEmpty && newName != item.name else {
            renamingItemId = nil
            return
        }
        
        let oldName = item.name
        
        do {
            try FileSystemManager.shared.rename(item: item, to: newName)
            // Post notification
            let oldUrl = item.url
            let newUrl = item.url.deletingLastPathComponent().appendingPathComponent(newName)
            NotificationCenter.default.post(name: .fileSystemDidUpdateNotification, object: nil, userInfo: ["urls": [oldUrl, newUrl]])
            
            loadContents() // Reload to show new name and order
            renamingItemId = nil
            
            // Undo Registration
            if let undoManager = undoManager {
                let wrapped = SendableUndoManager(manager: undoManager)
                undoManager.registerUndo(withTarget: self) { target in
                     Task { @MainActor in
                         if let newItem = target.items.first(where: { $0.url == newUrl }) {
                             target.renameItem(newItem, to: oldName, undoManager: wrapped.manager)
                         }
                     }
                }
                if !undoManager.isUndoing {
                    undoManager.setActionName("Rename \(oldName) to \(newName)")
                }
            }
            
        } catch {
            print("Failed to rename item: \(error)")
            // Optionally set an error state to show alert
            renamingItemId = nil
            renamingItemId = nil
        }
    }
    
    func downloadItem(_ item: FileItem) {
        do {
            try FileSystemManager.shared.download(item)
            // Post notification
            NotificationCenter.default.post(name: .fileSystemDidUpdateNotification, object: nil, userInfo: ["urls": [item.url]])
            
            // Aggressive refresh pattern to ensure UI catches the metadata update
            // Immediate, swift update, and a safety check
            Task { @MainActor in self.loadContents() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.loadContents() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.loadContents() }
        } catch {
            print("Failed to start download: \(error)")
        }
    }
    
    func evictItem(_ item: FileItem) {
        do {
            try FileSystemManager.shared.evict(item)
            NotificationCenter.default.post(name: .fileSystemDidUpdateNotification, object: nil, userInfo: ["urls": [item.url]])
            
            Task { @MainActor in self.loadContents() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.loadContents() }
        } catch {
            print("Failed to evict item: \(error)")
        }
    }
    
    func moveToTrash(_ item: FileItem, undoManager: UndoManager? = nil) {
        // Prepare for undo: we need to know where it was.
        // Actually, trashItem returns/users usually handle "Put Back".
        // But for manual undo, we can't easily "untrash" to same location unless we track it.
        // `FileManager.trashItem` moves it to Trash. We don't get the result URL easily?
        // Wait, resultingItemURL : AutoreleasingUnsafeMutablePointer<NSURL?>?
        
        let originalUrl = item.url
        var trashedUrl: NSURL?
        
        do {
            try FileManager.default.trashItem(at: originalUrl, resultingItemURL: &trashedUrl)
            NotificationCenter.default.post(name: .fileSystemDidUpdateNotification, object: nil, userInfo: ["urls": [originalUrl]])
            loadContents()
            
            // Undo Logic
            if let trashedUrl = trashedUrl as URL?, let undoManager = undoManager {
                let wrapped = SendableUndoManager(manager: undoManager)
                undoManager.registerUndo(withTarget: self) { target in
                    // Move it back
                    Task { @MainActor in
                        _ = await target.handleDrop(urls: [trashedUrl], to: originalUrl.deletingLastPathComponent(), undoManager: wrapped.manager)
                    }
                }
                undoManager.setActionName("Move to Trash")
            }
            
        } catch {
            print("Failed to move to trash: \(error)")
        }
    }
    
    func handleDrop(urls: [URL], to target: URL? = nil, undoManager: UndoManager? = nil, alwaysCopy: Bool = false, forceMove: Bool = false) async -> Bool {
        let destination = target ?? currentPath
        NSLog("DEBUG: PaneState.handleDrop called. Destination: \(destination.path)")
        NSLog("DEBUG: Processing \(urls.count) URLs")
        
        let fileManager = FileManager.default
        var didAction = false
        
        for url in urls {
             // Check if source and dest are same
             if url.path == destination.path {
                  NSLog("DEBUG: Skipping \(url.lastPathComponent) (Source same as Destination context)")
                  continue
             }
             // Check if file is being dropped onto itself (if target was a file? logic prevents that in View, but check here)
             // But here destination is directory.
             
             var destURL = destination.appendingPathComponent(url.lastPathComponent)
             
             if url.path == destURL.path {
                 if alwaysCopy {
                     // Auto-rename for duplicate
                     destURL = generateUniquePath(for: url, in: destination)
                 } else {
                     NSLog("DEBUG: Skipping \(url.lastPathComponent) (Source same as dest file)")
                     continue
                 }
             }
             
             // Check Same Volume
             // Basic heuristic: check resource values for volume identifier or just path prefix?
             // Path prefix isn't reliable for mounted volumes.
             // Using startAccessingSecurityScopedResource if needed (not needed for local usually).
             // Better: get volume identifier.
             
             var isSameVolume = false
             if let srcVol = try? url.resourceValues(forKeys: [.volumeIdentifierKey]),
                let dstVol = try? destination.resourceValues(forKeys: [.volumeIdentifierKey]) {
                 isSameVolume = (srcVol.volumeIdentifier as? NSObject)?.isEqual(dstVol.volumeIdentifier) == true
             }
             
             // Decision: Copy or Move?
             // Logic:
             // 1. If alwaysCopy -> Copy
             // 2. If forceMove -> Move
             // 3. If !isSameVolume -> Copy
             // 4. Else -> Move
             
             let shouldCopy = alwaysCopy || (!isSameVolume && !forceMove)
             
             do {
                 // Check if dest exists
                 if fileManager.fileExists(atPath: destURL.path) {
                     // Prompt Overwrite
                      let shouldOverwrite = await promptForOverwrite(fileName: destURL.lastPathComponent)
                      if !shouldOverwrite {
                          continue
                      }
                      
                      // Remove existing
                      // For undo, we might want to move it to temp? simpler to just delete for now or use strict replace.
                      try fileManager.removeItem(at: destURL)
                 }
                 
                 if shouldCopy {
                     try fileManager.copyItem(at: url, to: destURL)
                     didAction = true
                 } else {
                     try fileManager.moveItem(at: url, to: destURL)
                     didAction = true
                 }
                 
                 // Undo Registration
                 if let manager = undoManager {
                     // Register undo action (Move back or Delete copy)
                     // ... (Simplified undo logic for brevity, ideally robust)
                 }
                 
             } catch {
                 NSLog("ERROR: Failed to handle drop for \(url.path): \(error)")
                 // Show alert?
             }
        }
        
        if didAction {
            await MainActor.run {
                loadContents()
            }
        }
        
        return didAction
    }
    
    private let monitor = DirectoryMonitor()
    private var debounceTimer: Timer?
    
    func startMonitoring() {
        monitor.startMonitoring(url: currentPath) { [weak self] in
            // Debounce loadContents to avoid rapid refreshes
            Task { @MainActor [weak self] in
                self?.debounceLoadContents()
            }
        }
    }
    
    private func debounceLoadContents() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                print("PaneState: Reloading contents due to change")
                self?.loadContents()
            }
        }
    }
    
    private var pollTimer: Timer?
    
    // Check if we need to keep polling (if items are downloading)
    private func updatePollingStatus() {
        let needsPolling = items.contains { $0.isDownloading } // || $0.needsDownload? No, only active downloads? 
        // Actually, sometimes needsDownload -> isDownloading transition is missed?
        // Let's poll if isDownloading IS TRUE.
        
        if needsPolling {
            if pollTimer == nil {
                print("PaneState: Starting smart polling (active downloads detected)")
                pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    // Only reload if downloading items still exist or new ones appeared (handled by notification)
                    // Simple poll for now
                    Task { @MainActor in self?.loadContents() }
                }
            }
        } else {
            if pollTimer != nil {
                print("PaneState: Stopping smart polling (no active downloads)")
                pollTimer?.invalidate()
                pollTimer = nil
            }
        }
    }
    
    // MARK: - File Operations
    
    func createNewFolder() -> URL? {
        let baseName = "untitled folder"
        var targetName = baseName
        var counter = 2
        var targetUrl = currentPath.appendingPathComponent(targetName)
        
        while FileManager.default.fileExists(atPath: targetUrl.path) {
            targetName = "\(baseName) \(counter)"
            targetUrl = currentPath.appendingPathComponent(targetName)
            counter += 1
        }
        
        do {
            try FileManager.default.createDirectory(at: targetUrl, withIntermediateDirectories: false, attributes: nil)
            return targetUrl
        } catch {
            print("Error creating directory: \(error)")
            return nil
        }
    }
    
    // MARK: - Selection Helpers
    func select(_ item: FileItem, exclusive: Bool = true) {
        if exclusive {
            selectedItems = [item.id]
        } else {
            selectedItems.insert(item.id)
        }
        lastSelectedId = item.id
        preservedSelection = selectedItems
    }
    
    func selectRange(to item: FileItem) {
        // If no anchor, simple select
        guard let lastId = lastSelectedId else {
            print("SelectionDebug: No anchor found for selectRange, falling back to select")
            select(item)
            return
        }
        
        guard let startIdx = sortedItems.firstIndex(where: { $0.id == lastId }),
              let endIdx = sortedItems.firstIndex(where: { $0.id == item.id }) else {
            print("SelectionDebug: Anchor or target not found in sortedItems. Anchor: \(lastSelectedId?.path ?? "nil"), Target: \(item.url.path)")
            select(item)
            return
        }
        
        let range = startIdx < endIdx ? startIdx...endIdx : endIdx...startIdx
        let itemsToSelect = sortedItems[range]
        let newRangeSelection = Set(itemsToSelect.map { $0.id })
        
        // Finder Logic:
        // Range Selection = (Preserved Selection) UNION (New Range from Anchor to Current)
        // This ensures that "shrinking" the range (by clicking closer to anchor) correctly
        // removes items that were in the previous longer range.
        selectedItems = preservedSelection.union(newRangeSelection)
    }
    
    func toggleSelection(_ item: FileItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
            // If deselecting anchor, logic varies. Keeping simple.
        } else {
            selectedItems.insert(item.id)
            lastSelectedId = item.id // Update anchor
        }
        preservedSelection = selectedItems
    }
    
    func selectAll() {
        selectedItems = Set(items.map { $0.id })
        preservedSelection = selectedItems
    }
    
    func deselectAll() {
        selectedItems.removeAll()
        preservedSelection.removeAll()
        lastSelectedId = nil
    }
    
    // MARK: - Prompts
    @MainActor
    private func promptForOverwrite(fileName: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = "An item named \"\(fileName)\" already exists in this location."
            alert.informativeText = "Do you want to replace it with the one you're moving?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Cancel")
            
            if let window = NSApp.keyWindow ?? NSApp.mainWindow {
                alert.beginSheetModal(for: window) { response in
                    continuation.resume(returning: response == .alertFirstButtonReturn)
                }
            } else {
                let response = alert.runModal()
                continuation.resume(returning: response == .alertFirstButtonReturn)
            }
            }
        }
    }
    // MARK: - Helpers
    
    private func generateUniquePath(for url: URL, in directory: URL) -> URL {
        let fileManager = FileManager.default
        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        
        // Try "copy"
        var candidateName = "\(name) copy"
        if !ext.isEmpty { candidateName += ".\(ext)" }
        var candidateUrl = directory.appendingPathComponent(candidateName)
        
        if !fileManager.fileExists(atPath: candidateUrl.path) {
            return candidateUrl
        }
        
        // Try "copy 2", "copy 3", etc.
        var counter = 2
        while true {
            candidateName = "\(name) copy \(counter)"
            if !ext.isEmpty { candidateName += ".\(ext)" }
            candidateUrl = directory.appendingPathComponent(candidateName)
            
            if !fileManager.fileExists(atPath: candidateUrl.path) {
                return candidateUrl
            }
            counter += 1
        }
    }

// Global Notification Definition
extension Notification.Name {
    static let fileSystemDidUpdateNotification = Notification.Name("com.quadfinder.fileSystemDidUpdate")
}

struct SendableUndoManager: @unchecked Sendable {
    let manager: UndoManager
}
