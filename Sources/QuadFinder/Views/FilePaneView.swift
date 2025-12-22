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
import UniformTypeIdentifiers

struct FilePaneView: View {
    @ObservedObject var state: PaneState
    @Binding var activePaneId: UUID?
    
    @FocusState private var isPathFocused: Bool
    @State private var pathInput: String = ""
    
    @State private var isRenamingTitle: Bool = false
    @State private var tempTitle: String = ""
    @FocusState private var isTitleFocused: Bool
    
    @Environment(\.undoManager) var undoManager
    
    // Column Widths
    // Column Widths
    @State private var nameColumnWidth: CGFloat = 200
    @State private var kindColumnWidth: CGFloat = 100
    @State private var dateColumnWidth: CGFloat = 150
    
    var isActive: Bool {
        activePaneId == state.id
    }
    
    // Quick auto-resize logic
    private func autoResizeColumn(_ column: PaneState.SortOption) {
        let padding: CGFloat = 20
        
        func measure(_ text: String, size: CGFloat) -> CGFloat {
            let font = NSFont.systemFont(ofSize: size)
            let attributes = [NSAttributedString.Key.font: font]
            return NSAttributedString(string: text, attributes: attributes).size().width
        }
        
        switch column {
        case .name:
            let maxWidth = state.items.lazy.map { measure($0.name, size: NSFont.systemFontSize) }.max() ?? 50
            nameColumnWidth = maxWidth + padding + 20 // +20 for icon
        case .kind:
            let maxWidth = state.items.lazy.map { measure($0.kind, size: NSFont.smallSystemFontSize) }.max() ?? 50
            kindColumnWidth = maxWidth + padding
        case .date:
            // Date is usually fixed length, but good to have
            // Measure a sample date string
            let sample = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
            let maxWidth = measure(sample, size: NSFont.smallSystemFontSize) + 20 // buffer
            dateColumnWidth = max(100, maxWidth + padding)
        case .size:
            break // Legacy code, no-op
        }
    }
    
    private func toggleSort(_ option: PaneState.SortOption) {
        if state.sortOption == option {
            state.sortOrder = state.sortOrder == .ascending ? .descending : .ascending
        } else {
            state.sortOption = option
            state.sortOrder = .ascending
        }
    }
    
    private func sortIndicator(for option: PaneState.SortOption) -> String {
        guard state.sortOption == option else { return "" }
        return state.sortOrder == .ascending ? " ^" : " v"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Pane Header (Custom Title)
            ZStack {
                Rectangle()
                    .fill(isActive ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
                
                if isRenamingTitle {
                    TextField("Title", text: $tempTitle)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 13, weight: .bold))
                        .padding(4)
                        .background(Color(nsColor: .textBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor, lineWidth: 1))
                        .onSubmit {
                            state.customTitle = tempTitle.isEmpty ? nil : tempTitle
                            isRenamingTitle = false
                        }
                        .focused($isTitleFocused)
                        .onExitCommand {
                            isRenamingTitle = false
                        }
                } else {
                    Text(state.customTitle ?? state.currentPath.lastPathComponent)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isActive ? .primary : .secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            tempTitle = state.customTitle ?? state.currentPath.lastPathComponent
                            isRenamingTitle = true
                            isTitleFocused = true
                        }
                }
            }
            .frame(height: 28)
            .border(Color(nsColor: .separatorColor), width: 0.5)

            // Re-using previous header/nav bar code...
            // Header / Navigation Bar
            HStack(spacing: 4) {
                Button(action: state.goBack) {
                    Image(systemName: "arrow.left")
                }
                .disabled(state.backStack.isEmpty)
                
                Button(action: state.goForward) {
                    Image(systemName: "arrow.right")
                }
                .disabled(state.forwardStack.isEmpty)

                Button(action: state.goUp) {
                    Image(systemName: "arrow.up")
                }
                .disabled(state.currentPath.path == "/")
                
                // Editable Path Bar
                TextField("Path", text: $pathInput)
                    .focused($isPathFocused)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        let url = URL(fileURLWithPath: pathInput)
                        state.navigateTo(url)
                    }
                    .onChange(of: state.currentPath) { newPath in
                        pathInput = newPath.path
                    }
                    .onAppear {
                        pathInput = state.currentPath.path
                    }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            // Quick Look Shortcut
            .background(
                Group {
                    if isActive && state.renamingItemId == nil && !isPathFocused {
                        Button("QuickLook") {
                            if let selectedId = state.selectedItems.first,
                               let item = state.items.first(where: { $0.id == selectedId }) ?? state.searchResults.first(where: { $0.id == selectedId }) {
                                
                                if item.needsDownload {
                                    state.downloadItem(item)
                                    // Optional: Wait for download? 
                                    // Realistically, QL might fail until downloaded. 
                                    // We trigger download now. User might need to press space again or we wait?
                                    // User request: "Before QL, auto download".
                                    // Simply calling download works. QL might show placeholder or loading if OS handles it
                                    // But let's trigger QL anyway, OS QuickLook usually handles "Downloading" UI if file is ubiquitous.
                                    QuickLookHelper.shared.togglePreview(for: item.url)
                                } else {
                                    QuickLookHelper.shared.togglePreview(for: item.url)
                                }
                            }
                        }
                        .keyboardShortcut(.space, modifiers: [])
                        .keyboardShortcut(.space, modifiers: [])
                        .opacity(0)
                        
                        // Get Info Shortcut (Cmd+I)
                        Button("Get Info Host") {
                             if let selectedId = state.selectedItems.first,
                                let item = state.items.first(where: { $0.id == selectedId }) ?? state.searchResults.first(where: { $0.id == selectedId }) {
                                 state.infoItem = item
                             }
                        }
                        .keyboardShortcut("i", modifiers: .command)
                        .opacity(0)
                    }
                }
            )
            
            // Search Bar
            if state.isSearching {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search...", text: $state.searchQuery)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            state.performSearch()
                        }
                    if !state.searchQuery.isEmpty {
                        Button(action: { state.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .border(Color.gray.opacity(0.2), width: 1)
                .onChange(of: state.searchQuery) { newValue in
                     if newValue.isEmpty { state.searchResults = [] }
                }
            }

            // Content Area with FileListView
            GeometryReader { geometry in
            // Content Area with FileListView
            GeometryReader { geometry in
                FileListView(state: state, onFocus: {
                    if activePaneId != state.id {
                        activePaneId = state.id
                        isPathFocused = false
                        state.renamingItemId = nil
                    }
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(state.currentPath)
                .onDrop(of: [UTType.fileURL], isTargeted: nil, perform: handleMainDrop)
            }
            }
            
            // Path Bar (Breadcrumbs)
            PathBarView(state: state)
        }
        .border(isActive ? Color.accentColor : Color.gray.opacity(0.3), width: isActive ? 2 : 1)
        .sheet(item: $state.infoItem) { item in
            FileInfoView(item: item, isPresented: Binding(
                get: { state.infoItem != nil },
                set: { if !$0 { state.infoItem = nil } }
            ))
        }
        .onTapGesture {
            activePaneId = state.id
            isPathFocused = false
            state.renamingItemId = nil
        }
        .onAppear {
            if state.items.isEmpty {
                state.loadContents()
            }
        }
        .background(MouseNavView(
            isActive: isActive,
            onBack: { state.goBack() },
            onForward: { state.goForward() }
        ))
        .background(
            Button("") {
                copySelection()
            }
            .keyboardShortcut("c", modifiers: .command)
            .disabled(!isActive)
            .opacity(0)
        )
        .background(
             Button("") {
                 pasteItems()
             }
             .keyboardShortcut("v", modifiers: .command)
             .disabled(!isActive)
             .opacity(0)
        )
    }
    
    private func copySelection() {
        let urls = state.items.filter { state.selectedItems.contains($0.id) }.map { $0.url as NSURL }
        guard !urls.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls)
        print("Copied \(urls.count) items to pasteboard")
    }
    
    private func pasteItems() {
        guard NSPasteboard.general.canReadObject(forClasses: [NSURL.self], options: nil) else { return }
        
        guard let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty else { return }
        
        print("Pasting \(urls.count) items")
        Task {
            await state.handleDrop(urls: urls, undoManager: undoManager)
        }
    }
    
    private func handleMainDrop(_ providers: [NSItemProvider]) -> Bool {
        NSLog("DEBUG: handleMainDrop called with \(providers.count) providers")
        
        // Internal Drag Check
        if !DraggingManager.shared.draggingUrls.isEmpty {
            NSLog("DEBUG: Internal Main Drop detected with \(DraggingManager.shared.draggingUrls.count) items")
            let urls = DraggingManager.shared.draggingUrls
            Task {
                await state.handleDrop(urls: urls, undoManager: undoManager)
            }
            DraggingManager.shared.clear()
            return true
        }

        let group = DispatchGroup()
        let collector = UrlCollector()
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                 defer { group.leave() }
                 if let url = url {
                     collector.add(url)
                 }
            }
        }
        
        group.notify(queue: .main) {
            guard !collector.urls.isEmpty else { return }
            Task {
                await state.handleDrop(urls: collector.urls, undoManager: undoManager)
            }
        }
        return true
    }
}

struct MouseNavView: NSViewRepresentable {
    let isActive: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    
    func makeNSView(context: Context) -> MouseEventHandlerView {
        let view = MouseEventHandlerView()
        view.onBack = onBack
        view.onForward = onForward
        view.isActive = isActive
        return view
    }
    
    func updateNSView(_ nsView: MouseEventHandlerView, context: Context) {
        nsView.isActive = isActive
        nsView.onBack = onBack
        nsView.onForward = onForward
    }
}

class MouseEventHandlerView: NSView {
    var isActive: Bool = false
    var onBack: (() -> Void)?
    var onForward: (() -> Void)?
    private var monitor: Any?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Remove existing if any
        cleanupMonitor()
        
        // Add local monitor to catch button presses anywhere in the window
        if self.window != nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseUp]) { [weak self] event in
                guard let self = self, self.isActive else { return event }
                
                print("Mouse Event Detected: Button \(event.buttonNumber)")
                
                if event.buttonNumber == 3 {
                    self.onBack?()
                    return nil // Consume event
                } else if event.buttonNumber == 4 {
                    self.onForward?()
                    return nil // Consume event
                }
                return event
            }
        }
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            cleanupMonitor()
        }
    }
    
    private func cleanupMonitor() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

class UrlCollector: @unchecked Sendable {
    var urls: [URL] = []
    private let lock = NSLock()
    
    func add(_ url: URL) {
        lock.lock()
        urls.append(url)
        lock.unlock()
    }
}
