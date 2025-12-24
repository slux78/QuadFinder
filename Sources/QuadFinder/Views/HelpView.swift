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

struct HelpView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                Text("QuadFinder")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Powerful 4-Pane File Manager")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Features
                    SectionView(title: "Features", items: [
                        "Four independent file panes for efficient multitasking.",
                        "Drag and drop files between panes.",
                        "Maximize any pane with a shortcut.",
                        "Quickly search files within any pane.",
                        "Integrated Terminal and Finder actions."
                    ])
                    
                    Divider()
                    
                    // Shortcuts
                    Text("Keyboard Shortcuts")
                        .font(.headline)
                    
                    ShortcutsTable()
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct SectionView: View {
    let title: String
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top) {
                    Text("•")
                    Text(item)
                }
                .font(.body)
            }
        }
    }
}

struct ShortcutsTable: View {
    let shortcuts = [
        ("Add to Favorites", "Ctrl + D"),
        ("Go to Favorite", "Ctrl + G"),
        ("Maximize / Restore Pane", "Ctrl + Shift + Enter"),
        ("Find / Search", "⌘ + F"),
        ("Get Info", "⌘ + I"),
        ("Quick Look", "Space"),
        ("Copy", "⌘ + C"),
        ("Paste", "⌘ + V"),
        ("New Folder", "Right Click -> New Folder"),
        ("Rename", "Click Name or Right Click")
    ]
    
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
            ForEach(shortcuts, id: \.0) { action, key in
                GridRow {
                    Text(action)
                    Text(key)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
    }
}
