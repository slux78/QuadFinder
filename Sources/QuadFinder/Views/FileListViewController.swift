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

import Cocoa
import SwiftUI
import Combine
import UniformTypeIdentifiers

class FileListViewController: NSViewController, @preconcurrency NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate, NSTextFieldDelegate {
    
    var paneState: PaneState?
    var onFocus: (() -> Void)?
    var cancellables = Set<AnyCancellable>()
    
    let tableView = QuadTableView()
    let scrollView = NSScrollView()
    
    // Identifier for column
    let colName = NSUserInterfaceItemIdentifier("NameColumn")
    let colSize = NSUserInterfaceItemIdentifier("SizeColumn")
    let colDate = NSUserInterfaceItemIdentifier("DateColumn")
    let colKind = NSUserInterfaceItemIdentifier("KindColumn")
    
    override func loadView() {
        self.view = NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup ScrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true 
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // Setup TableView
        tableView.delegate = self
        tableView.dataSource = self
        
        // Custom Focus Handling
        tableView.onMouseDown = { [weak self] in
            self?.onFocus?()
        }
        
        let headerView = QuadTableHeaderView()
        headerView.fileListController = self
        tableView.headerView = headerView
        
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.rowHeight = 24
        tableView.style = .fullWidth
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.allowsColumnResizing = true
        
        // Drag and Drop Registration
        tableView.registerForDraggedTypes([.fileURL])
        tableView.setDraggingSourceOperationMask(.every, forLocal: false)
        
        // Add Columns
        let cName = NSTableColumn(identifier: colName)
        cName.title = "Name"
        cName.width = 250
        cName.minWidth = 100
        cName.maxWidth = 10000
        cName.resizingMask = [.userResizingMask, .autoresizingMask]
        cName.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
        tableView.addTableColumn(cName)
        
        let cSize = NSTableColumn(identifier: colSize)
        cSize.title = "Size"
        cSize.width = 80
        cSize.minWidth = 50
        cSize.maxWidth = 1000
        cSize.resizingMask = [.userResizingMask, .autoresizingMask]
        cSize.sortDescriptorPrototype = NSSortDescriptor(key: "size", ascending: true)
        tableView.addTableColumn(cSize)
        
        let cDate = NSTableColumn(identifier: colDate)
        cDate.title = "Date Modified"
        cDate.width = 150
        cDate.minWidth = 100
        cDate.maxWidth = 1000
        cDate.resizingMask = [.userResizingMask, .autoresizingMask]
        cDate.sortDescriptorPrototype = NSSortDescriptor(key: "dateModified", ascending: false)
        tableView.addTableColumn(cDate)
        
        let cKind = NSTableColumn(identifier: colKind)
        cKind.title = "Kind"
        cKind.width = 150
        cKind.minWidth = 80
        cKind.maxWidth = 1000
        cKind.resizingMask = [.userResizingMask, .autoresizingMask]
        cKind.sortDescriptorPrototype = NSSortDescriptor(key: "kind", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
        tableView.addTableColumn(cKind)
        
        
        scrollView.documentView = tableView
        
        // Double Click Action
        tableView.target = self
        tableView.doubleAction = #selector(onDoubleClick)
        
        // Context Menu
        let menu = NSMenu()
        menu.delegate = self
        tableView.menu = menu
        
        setupBindings()
    }
    
    func setupBindings() {
        // No-op for now unless we add specific combine subscriptions
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let state = paneState, let sortDescriptor = tableView.sortDescriptors.first else { return }
        
        // Map NSSortDescriptor key to PaneState.SortOption
        if let key = sortDescriptor.key {
            switch key {
            case "name":
                state.sortOption = .name
            case "size":
                state.sortOption = .size
            case "dateModified":
                state.sortOption = .date
            case "kind":
                state.sortOption = .kind
            default:
                break
            }
            
            state.sortOrder = sortDescriptor.ascending ? .ascending : .descending
            
            // Reload done by update() loop or manual trigger? 
            // state update triggers swiftui body -> update(with:) -> reloadData if items change.
            // But changing sort order changes "sortedItems" computer property sequence, not necessarily the IDs if the set is same?
            // Wait, my check is: let newIds = state.sortedItems.map { $0.id }
            // If order changes, the array of IDs changes! So it will reload.
            
            // However, we should also invoke reload to be sure or force update.
            // But state.objectWillChange should trigger View update.
        }
    }
    
    // State tracking to prevent loops
    private var lastItemsId: UUID? 
    private var lastItemIds: [URL] = []
    
    // Called by wrapper when state updates
    func update(with state: PaneState) {
        self.paneState = state
        
        // Check if items changed
        let newIds = state.sortedItems.map { $0.id }
        if newIds != lastItemIds {
            lastItemIds = newIds
            tableView.reloadData()
        }
        
        // Sync Selection FROM State TO Table
        syncSelectionFromState()
    }
    
    func syncSelectionFromState() {
        guard let state = paneState else { return }
        
        // Convert URLs to Indexes
        var indexes = IndexSet()
        for (index, item) in state.sortedItems.enumerated() {
            if state.selectedItems.contains(item.id) {
                indexes.insert(index)
            }
        }
        
        // Check if different to avoid loop
        if tableView.selectedRowIndexes != indexes {
            tableView.selectRowIndexes(indexes, byExtendingSelection: false)
        }
    }
    
    @objc func onDoubleClick() {
        onFocus?()
        guard let state = paneState else { return }
        let clickedRow = tableView.clickedRow
        
        if clickedRow >= 0 && clickedRow < state.sortedItems.count {
            let item = state.sortedItems[clickedRow]
            
            if item.isDirectory && !item.isPackage {
                state.navigateTo(item.url)
            } else if item.url.pathExtension.lowercased() == "dmg" {
                mountDMG(at: item.url)
            } else {
                NSWorkspace.shared.open(item.url)
            }
        }
    }
    
    private func mountDMG(at url: URL) {
        let task = Process()
        task.launchPath = "/usr/bin/hdiutil"
        task.arguments = ["attach", url.path]
        
        do {
            try task.run()
            // Optional: Show some feedback or wait?
            // Sidebar will auto-update via Notification.
        } catch {
            print("Failed to mount DMG: \(error)")
            let alert = NSAlert()
            alert.messageText = "Failed to mount disk image"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
    
     // MARK: - Menu Delegate
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        onFocus?()
        menu.removeAllItems()
        
        let row = tableView.clickedRow
        guard let state = paneState else { return }
        
        // If clicked on a row (clickedRow != -1)
        if row >= 0 {
             // If the clicked row is NOT in the selection, select it (exclusive)
             if !tableView.selectedRowIndexes.contains(row) {
                 tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
             }
        } else {
             // Clicked on empty space
             tableView.deselectAll(nil)
             // Allow showing menu for current directory actions
        }
        
        // Items Context
        if !state.selectedItems.isEmpty {
            menu.addItem(withTitle: "Open", action: #selector(onOpenItem), keyEquivalent: "")
            menu.addItem(withTitle: "Show in Finder", action: #selector(onShowInFinder), keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())
            menu.addItem(withTitle: "Rename", action: #selector(onRenameItem), keyEquivalent: "")
            menu.addItem(withTitle: "Get Info", action: #selector(onGetInfo), keyEquivalent: "i")
            menu.addItem(NSMenuItem.separator())
            menu.addItem(withTitle: "Copy Path", action: #selector(onCopyPath), keyEquivalent: "")
            menu.addItem(withTitle: "Terminal Here", action: #selector(onTerminalHere), keyEquivalent: "")

            // Cloud Actions
            if let first = state.selectedItems.first,
               let item = state.items.first(where: { $0.id == first }),
               item.downloadingStatus != nil {
                
                menu.addItem(NSMenuItem.separator())
                
                if item.downloadingStatus == .notDownloaded {
                     let dlItem = NSMenuItem(title: "Download Now", action: #selector(onDownloadItem), keyEquivalent: "")
                     dlItem.image = NSImage(systemSymbolName: "icloud.and.arrow.down", accessibilityDescription: "Download")
                     menu.addItem(dlItem)
                } else {
                     let evictItem = NSMenuItem(title: "Remove Download", action: #selector(onEvictItem), keyEquivalent: "")
                     evictItem.image = NSImage(systemSymbolName: "icloud.slash", accessibilityDescription: "Remove Download")
                     menu.addItem(evictItem)
                }
            }

            menu.addItem(NSMenuItem.separator())
            
            let trashItem = NSMenuItem(title: "Move to Trash", action: #selector(onMoveToTrash), keyEquivalent: "")
            trashItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Trash")
            menu.addItem(trashItem)
        } else {
            // Empty Space Context (Current Directory)
            menu.addItem(withTitle: "New Folder", action: #selector(onNewFolder), keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())
            menu.addItem(withTitle: "Get Info", action: #selector(onGetInfo), keyEquivalent: "i")
            menu.addItem(withTitle: "Copy Path", action: #selector(onCopyPath), keyEquivalent: "")
            menu.addItem(withTitle: "Terminal Here", action: #selector(onTerminalHere), keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())
            menu.addItem(withTitle: "Show in Finder", action: #selector(onShowInFinder), keyEquivalent: "")
        }
    }
    
    @objc func onNewFolder() {
        guard let state = paneState else { return }
        if let newUrl = state.createNewFolder() {
            // Reload and select
            Task { @MainActor in
                state.loadContents()
                // Wait briefly for reload
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                if let item = state.items.first(where: { $0.url == newUrl }) {
                    state.select(item)
                    // Trigger rename?
                    // We need to wait for view update.
                    // Let's rely on user to rename for now or try:
                    self.onRenameItem()
                }
            }
        }
    }
    
    @objc func onOpenItem() {
        onDoubleClick() 
    }
    
    @objc func onShowInFinder() {
        guard let state = paneState else { return }
        
        let urls: [URL]
        if !state.selectedItems.isEmpty {
            urls = state.selectedItems.compactMap { id in state.items.first(where: { $0.id == id })?.url }
        } else {
            urls = [state.currentPath]
        }
        
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
    
    @objc func onRenameItem() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        
        // Delay slightly to ensure cell view is ready if called immediately after selection
        DispatchQueue.main.async {
            let view = self.tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView
            view?.textField?.becomeFirstResponder()
        }
    }
    
    @objc func onGetInfo() {
         guard let state = paneState else { return }
         if let first = state.selectedItems.first, let item = state.items.first(where: { $0.id == first }) {
             state.infoItem = item
         } else if state.selectedItems.isEmpty {
             // Empty selection -> Info for current folder?
             // We need a FileItem for the current folder. 
             // We can construct a temporary one or fetch it?
             // PaneState doesn't store 'currentFolderItem' directly easily.
             // Let's Skip for now or try to create one.
             // Construct FileItem for current directory
             let path = state.currentPath.path
             let attr = try? FileManager.default.attributesOfItem(atPath: path)
             let modDate = attr?[.modificationDate] as? Date ?? Date()
             let createDate = attr?[.creationDate] as? Date ?? Date()
             
             let item = FileItem(
                 name: state.currentPath.lastPathComponent,
                 url: state.currentPath,
                 isDirectory: true,
                 isPackage: false,
                 isSymbolicLink: false,
                 downloadingStatus: nil,
                 isDownloading: false,
                 dateModified: modDate,
                 dateCreated: createDate,
                 size: nil // Folders usually nil size in this model
             )
             state.infoItem = item
         }
    }
    
    @objc func onCopyPath() {
        guard let state = paneState else { return }
        let urls: [String]
        
        if !state.selectedItems.isEmpty {
            urls = state.selectedItems.compactMap { id in state.items.first(where: { $0.id == id })?.url.path }
        } else {
            urls = [state.currentPath.path]
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls as [NSString])
    }
    
    @objc func onTerminalHere() {
         guard let state = paneState else { return }
         
         if let first = state.selectedItems.first, let item = state.items.first(where: { $0.id == first }) {
             openTerminal(at: item.url)
         } else {
             openTerminal(at: state.currentPath)
         }
    }
    
    @objc func onMoveToTrash() {
        guard let state = paneState else { return }
        let items = state.items.filter { state.selectedItems.contains($0.id) }
        for item in items {
            state.moveToTrash(item)
        }
    }
    
    @objc func onDownloadItem() {
        guard let state = paneState else { return }
        let items = state.items.filter { state.selectedItems.contains($0.id) }
        for item in items {
            state.downloadItem(item)
        }
    }
    
    @objc func onEvictItem() {
        guard let state = paneState else { return }
        let items = state.items.filter { state.selectedItems.contains($0.id) }
        for item in items {
            state.evictItem(item)
        }
    }
    
    private func openTerminal(at url: URL) {
        let workspace = NSWorkspace.shared
        var targetStart = url
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]), values.isDirectory == false {
             targetStart = url.deletingLastPathComponent()
        }
        
        let iTermId = "com.googlecode.iterm2"
        let terminalId = "com.apple.Terminal"
        let appId = workspace.urlForApplication(withBundleIdentifier: iTermId) != nil ? iTermId : terminalId
        
        if let appUrl = workspace.urlForApplication(withBundleIdentifier: appId) {
             workspace.open([targetStart], withApplicationAt: appUrl, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    
    // MARK: - DataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return paneState?.sortedItems.count ?? 0
    }
    
    // MARK: - Delegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let item = paneState?.sortedItems[row] else { return nil }
        guard let colParams = tableColumn else { return nil }
        
        let id = NSUserInterfaceItemIdentifier("Cell_\(colParams.identifier.rawValue)")
        var cell = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView
        
        if cell == nil {
            let newCell = NSTableCellView()
            newCell.identifier = id
            
            // Text Field
            let textField = NSTextField()
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.isEditable = false 
            textField.isBordered = false
            textField.drawsBackground = false
            textField.cell?.wraps = false
            textField.cell?.isScrollable = true
            newCell.addSubview(textField)
            newCell.textField = textField
            
            if colParams.identifier == colName {
                 let iconView = NSImageView()
                 iconView.translatesAutoresizingMaskIntoConstraints = false
                 iconView.imageScaling = .scaleProportionallyUpOrDown
                 newCell.addSubview(iconView)
                 newCell.imageView = iconView
                 
                 NSLayoutConstraint.activate([
                     iconView.leadingAnchor.constraint(equalTo: newCell.leadingAnchor, constant: 4),
                     iconView.centerYAnchor.constraint(equalTo: newCell.centerYAnchor),
                     iconView.widthAnchor.constraint(equalToConstant: 16),
                     iconView.heightAnchor.constraint(equalToConstant: 16),
                     
                     textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
                     textField.trailingAnchor.constraint(equalTo: newCell.trailingAnchor, constant: -4),
                     textField.centerYAnchor.constraint(equalTo: newCell.centerYAnchor)
                 ])
                 textField.isEditable = true // Editable name
                 textField.delegate = self
            } else {
                 NSLayoutConstraint.activate([
                     textField.leadingAnchor.constraint(equalTo: newCell.leadingAnchor, constant: 4),
                     textField.trailingAnchor.constraint(equalTo: newCell.trailingAnchor, constant: -4),
                     textField.centerYAnchor.constraint(equalTo: newCell.centerYAnchor)
                 ])
                 textField.textColor = .secondaryLabelColor
            }
            
            cell = newCell
        }
        
        // Config Cell
        if colParams.identifier == colName {
             cell?.textField?.stringValue = item.name
             cell?.imageView?.image = NSWorkspace.shared.icon(forFile: item.url.path)
             cell?.textField?.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        } else if colParams.identifier == colSize {
             if let size = item.size {
                 cell?.textField?.stringValue = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
             } else {
                 cell?.textField?.stringValue = "--"
             }
             cell?.textField?.alignment = .right
        } else if colParams.identifier == colDate {
             // Basic date format
             let formatter = DateFormatter()
             formatter.dateStyle = .medium
             formatter.timeStyle = .short
             cell?.textField?.stringValue = formatter.string(from: item.dateModified)
        } else if colParams.identifier == colKind {
             cell?.textField?.stringValue = item.kind
        }
        
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        onFocus?()
        guard let state = paneState else { return }
        
        let selectedIndexes = tableView.selectedRowIndexes
        var newSelection: Set<URL> = []
        
        let sorted = state.sortedItems
        for index in selectedIndexes {
            if index < sorted.count {
                newSelection.insert(sorted[index].id)
            }
        }
        
        // Sync Selection FROM Table TO State
        // Only update if changed to avoid loops (though Set comparison handles order)
        if state.selectedItems != newSelection {
             state.selectedItems = newSelection
             // Handling 'lastSelectedId' for range updates? 
             // NSTableView handles range selection internally physically.
             // We just need to sync the result state.
             
             // Update lastSelectedId if single selection?
             if selectedIndexes.count == 1, let first = selectedIndexes.first {
                 state.lastSelectedId = sorted[first].id
             }
        }
    }
    
    // MARK: - Drag and Drop
    

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard let state = paneState else { return nil }
        guard row >= 0 && row < state.sortedItems.count else { return nil }
        
        let item = state.sortedItems[row]
        return item.url as NSURL
    }
    
    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forRowIndexes rowIndexes: IndexSet) {
        guard let state = paneState else { return }
        
        var swiftUrls: [URL] = []
        let sorted = state.sortedItems
        
        rowIndexes.forEach { index in
            if index < sorted.count {
                swiftUrls.append(sorted[index].url)
            }
        }
        
        print("DEBUG: Drag Session Began. Items: \(swiftUrls.count)")
        DraggingManager.shared.draggingUrls = swiftUrls
    }
    
    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        print("DEBUG: Drag Session Ended. Operation: \(operation.rawValue)")
        
        if operation.contains(.delete) {
            print("DEBUG: operation contains .delete, moving items to trash")
            guard let state = paneState else { return }
            let urls = DraggingManager.shared.draggingUrls
            
            // Find items by URL and delete them
            // We use a Task because moveToTrash is async (or uses undoManager which might be better called from MainActor properly)
            // But moveToTrash in PaneState isn't async marked, but it calls async prompt if needed?
            // Actually `moveToTrash` in `PaneState` (from my memory) takes undoManager.
            // Let's check signature. 
            // `moveToTrash(_ item: FileItem, undoManager: UndoManager?)`
            
            if !urls.isEmpty {
                 Task { @MainActor in
                     for url in urls {
                         if let item = state.items.first(where: { $0.url == url }) {
                             state.moveToTrash(item, undoManager: self.undoManager)
                         }
                     }
                 }
            }
        }
        DraggingManager.shared.clear()
    }
    
    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .every
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard let state = paneState else { return [] }
        
        // Only allow dropping ON a folder (to move into it) or possibly between rows if we supported custom ordering (we don't).
        // For whitespace drop (row == -1 or after last), it means drop into CURRENT folder (the pane's path).
        
        if dropOperation == .on {
            // Check if target is a directory
            if row >= 0 && row < state.sortedItems.count {
                let targetItem = state.sortedItems[row]
                if targetItem.isDirectory && !targetItem.isPackage {
                    // Highlight the row? NSTableView does this automatically with .on
                    return .move // Or .copy depending on modifier keys, but .every is safer to let system decide default
                }
            }
        } else {
            // Drop in white space (into current directory)
            // We want to visually allow it.
             tableView.setDropRow(-1, dropOperation: .on) // Retarget to whole view essentially?
             // Actually, strictly dropping "between" rows doesn't make sense for sorted list.
             // We should interpret everything not "on" a folder as "into current background".
             return .move
        }
        
        print("DEBUG: validateDrop. Row: \(row), Op: \(dropOperation.rawValue). SourceMask: \(info.draggingSourceOperationMask.rawValue)")
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let state = paneState else { return false }
        let pboard = info.draggingPasteboard
        
        guard let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty else {
            print("DEBUG: acceptDrop failed to read URLs.")
            return false
        }
        
        print("DEBUG: acceptDrop read \(urls.count) URLs.")
        
        // Target:
        // If row >= 0 and .on, it's a specific subfolder.
        // If row == -1, it's the current folder (state.currentPath).
        
        var targetUrl = state.currentPath
        
        if row >= 0 && row < state.sortedItems.count && dropOperation == .on {
            let item = state.sortedItems[row]
            if item.isDirectory && !item.isPackage {
                targetUrl = item.url
            }
        }
        
        // Execute Drop
        Task { @MainActor in
            await state.handleDrop(urls: urls, to: targetUrl)
        }
        
        return true
    }

    // MARK: - Auto Resize Logic
    
    func autoSizeColumn(_ columnIndex: Int) {
        guard let state = paneState else { return }
        guard columnIndex >= 0 && columnIndex < tableView.tableColumns.count else { return }
        
        let column = tableView.tableColumns[columnIndex]
        let colId = column.identifier
        
        // Define Font attributes for measurement
        let cellFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let attrs = [NSAttributedString.Key.font: cellFont]
        
        var maxWidth: CGFloat = 0
        
        // Measure Title
        let titleWidth = (column.title as NSString).size(withAttributes: attrs).width + 20 // Padding
        maxWidth = titleWidth
        
        // Sample Limit to prevent UI freeze on huge lists
        let sampleLimit = 200
        let items = state.sortedItems
        var count = 0
        
        // Measure Content
        for item in items {
            if count > sampleLimit { break }
            count += 1
            
            var text = ""
            var extraPadding: CGFloat = 10
            
            if colId == colName {
                text = item.name
                extraPadding += 20 // Icon
            } else if colId == colSize {
                if let s = item.size {
                    text = ByteCountFormatter.string(fromByteCount: s, countStyle: .file)
                } else {
                    text = "--"
                }
            } else if colId == colDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                text = formatter.string(from: item.dateModified)
            } else if colId == colKind {
                text = item.kind
            }
            
            let width = (text as NSString).size(withAttributes: attrs).width + extraPadding
            if width > maxWidth {
                maxWidth = width
            }
        }
        
        // Apply limit
        if maxWidth > 1000 { maxWidth = 1000 }
        
        // Animate? No, just set.
        column.width = maxWidth
    }
    
    // MARK: - NSTextFieldDelegate
    
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        
        let row = tableView.row(for: textField)
        guard row >= 0, let state = paneState, row < state.sortedItems.count else { return }
        
        let item = state.sortedItems[row]
        let newName = textField.stringValue
        
        if newName != item.name {
            if !newName.isEmpty {
                state.renameItem(item, to: newName, undoManager: undoManager)
            } else {
                // Revert if empty
                textField.stringValue = item.name
            }
        }
    }
}

// MARK: - Custom Header View for Double Click Resize

class QuadTableHeaderView: NSTableHeaderView {
    
    weak var fileListController: FileListViewController?
    
    override func mouseDown(with event: NSEvent) {
        // Handle Double Click
        if event.clickCount == 2 {
            let point = self.convert(event.locationInWindow, from: nil)
            // Determine which column divider was clicked.
            // NSTableHeaderView doesn't easily expose "divider hit".
            // Heuristic: Check if point is near the right edge of a column.
            
            for (index, column) in tableView?.tableColumns.enumerated() ?? [].enumerated() {
                let rect = self.headerRect(ofColumn: index)
                // Divider is at the right edge.
                // Resizing zone is usually +/- 3 or 4 points from the edge.
                let dividerRange = (rect.maxX - 4)...(rect.maxX + 4)
                
                if dividerRange.contains(point.x) {
                    fileListController?.autoSizeColumn(index)
                    return // Consumed
                }
            }
        }
        
        super.mouseDown(with: event)
    }
}

class QuadTableView: NSTableView {
    var onMouseDown: (() -> Void)?
    
    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        super.mouseDown(with: event)
    }
}
