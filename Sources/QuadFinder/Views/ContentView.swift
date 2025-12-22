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
    
    var body: some View {
        GeometryReader { geometry in
            if let maxId = maximizedPaneId {
                // Maximized Mode
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
            } else {
                // Quad Mode
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
        .frame(minWidth: 800, minHeight: 600)
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
    }
}
