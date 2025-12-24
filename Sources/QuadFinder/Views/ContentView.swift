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


struct ContentView: View {
    @StateObject private var pane1 = PaneState()
    @StateObject private var pane2 = PaneState()
    @StateObject private var pane3 = PaneState()
    @StateObject private var pane4 = PaneState()
    
    @State private var activePaneId: UUID?
    @State private var maximizedPaneId: UUID? = nil
    
    @State private var vSplit: CGFloat = 0.5
    @State private var hSplitTop: CGFloat = 0.5
    @State private var hSplitBottom: CGFloat = 0.5
    
    @State private var sidebarWidth: CGFloat = 200
    
    var body: some View {
        HStack(spacing: 0) {
            SidebarView(activePaneId: $activePaneId, onNavigate: { url in
                navigateTo(url.path)
            })
            .frame(width: sidebarWidth)
            
            QuadResizeHandle(orientation: .horizontal, onDrag: { delta in
                let newWidth = sidebarWidth + delta
                sidebarWidth = max(150, min(400, newWidth))
            }, onReset: {
                withAnimation { sidebarWidth = 200 }
            })
            
            GeometryReader { geometry in
                if let maxId = maximizedPaneId {
                    maximizedView(maxId: maxId)
                } else {
                    quadLayout(geometry: geometry)
                }
            }
        }
        .frame(minWidth: 950, minHeight: 600)
        .onAppear {
            DispatchQueue.main.async {
                activePaneId = pane1.id // Default active
            }
        }
        .background(
            Button("Find") {
                if let activeId = activePaneId {
                    [pane1, pane2, pane3, pane4].first { $0.id == activeId }?.isSearching.toggle()
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            .opacity(0)
        )
        .background(
            Button("Toggle Maximize") {
                // Force any active text field (like rename) to commit changes
                NSApp.keyWindow?.makeFirstResponder(nil)
                
                if maximizedPaneId != nil {
                    maximizedPaneId = nil
                } else {
                    maximizedPaneId = activePaneId
                }
            }
            .keyboardShortcut(.return, modifiers: [.control, .shift])
            .opacity(0)
        )
        .background(
            WindowAccessor()
        )
        // Favorites Sheets
        .sheet(item: $activeSheetInfo) { info in
            AddFavoriteView(initialPath: info.path, onSave: { name, path in
                FavoritesManager.shared.add(name: name, path: path)
                activeSheetInfo = nil
            }, onCancel: {
                activeSheetInfo = nil
            })
        }
        .sheet(isPresented: $showingPickerFav) {
            FavoritesPickerView(onSelect: { path in
                navigateTo(path)
                showingPickerFav = false
            }, onCancel: {
                showingPickerFav = false
            })
        }
        // Favorites Shortcuts
        .onReceive(NotificationCenter.default.publisher(for: .requestAddFavorite)) { _ in
            if let path = currentActivePath {
                activeSheetInfo = ActiveSheetInfo(path: path)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestGoFavorites)) { _ in
            showingPickerFav = true
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)) { notification in
            guard let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
            let volumePath = url.path
            
            for pane in [pane1, pane2, pane3, pane4] {
                let current = pane.currentPath.path
                if current == volumePath || current.hasPrefix(volumePath + "/") {
                    pane.navigateTo(FileManager.default.homeDirectoryForCurrentUser)
                }
            }
        }
    }
    
    // MARK: - Favorites Helpers
    struct ActiveSheetInfo: Identifiable {
        let id = UUID()
        let path: String
    }
    
    @State private var activeSheetInfo: ActiveSheetInfo?
    @State private var showingPickerFav = false
    
    // Legacy removed: pendingAddFavoritePath, showingAddFav
    
    private var currentActivePath: String? {
        guard let activeId = activePaneId else {
            NSLog("DEBUG: activePaneId is nil")
            return nil
        }
        let pane = [pane1, pane2, pane3, pane4].first { $0.id == activeId }
        let path = pane?.currentPath.standardized.path
        NSLog("DEBUG: currentActivePath requested. Pane found: \(pane != nil). Path: '\(path ?? "nil")'")
        return path
    }
    
    private func navigateTo(_ path: String) {
        NSLog("DEBUG: navigateTo called with \(path)")
        guard let activeId = activePaneId else { return }
        if let pane = [pane1, pane2, pane3, pane4].first(where: { $0.id == activeId }) {
            pane.navigateTo(URL(fileURLWithPath: path))
        }
    }
    
    @ViewBuilder
    private func maximizedView(maxId: UUID) -> some View {
        Group {
            if maxId == pane1.id {
                FilePaneView(state: pane1, activePaneId: $activePaneId)
            } else if maxId == pane2.id {
                FilePaneView(state: pane2, activePaneId: $activePaneId)
            } else if maxId == pane3.id {
                FilePaneView(state: pane3, activePaneId: $activePaneId)
            } else if maxId == pane4.id {
                FilePaneView(state: pane4, activePaneId: $activePaneId)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func quadLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top Row
            HStack(spacing: 0) {
                FilePaneView(state: pane1, activePaneId: $activePaneId)
                    .frame(width: max(0, (geometry.size.width - 8) * hSplitTop))
                
                QuadResizeHandle(orientation: .horizontal, onDrag: { delta in
                    let totalWidth = geometry.size.width - 8
                    let newRatio = hSplitTop + (delta / totalWidth)
                    hSplitTop = max(0.1, min(0.9, newRatio))
                }, onReset: {
                    withAnimation { hSplitTop = 0.5 }
                })
                
                FilePaneView(state: pane2, activePaneId: $activePaneId)
            }
            .frame(height: max(0, (geometry.size.height - 8) * vSplit))
            
            // Vertical Divider
            QuadResizeHandle(orientation: .vertical, onDrag: { delta in
                let totalHeight = geometry.size.height - 8
                let newRatio = vSplit + (delta / totalHeight)
                vSplit = max(0.1, min(0.9, newRatio))
            }, onReset: {
                withAnimation { vSplit = 0.5 }
            })
            
            // Bottom Row
            HStack(spacing: 0) {
                FilePaneView(state: pane3, activePaneId: $activePaneId)
                    .frame(width: max(0, (geometry.size.width - 8) * hSplitBottom))
                
                QuadResizeHandle(orientation: .horizontal, onDrag: { delta in
                    let totalWidth = geometry.size.width - 8
                    let newRatio = hSplitBottom + (delta / totalWidth)
                    hSplitBottom = max(0.1, min(0.9, newRatio))
                }, onReset: {
                    withAnimation { hSplitBottom = 0.5 }
                })
                
                FilePaneView(state: pane4, activePaneId: $activePaneId)
            }
        }
    }
}
