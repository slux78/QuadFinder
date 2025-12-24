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

struct ManageFavoritesView: View {
    @ObservedObject var manager = FavoritesManager.shared
    @State private var showingAddSheet = false
    
    var body: some View {
        VStack {
            HStack {
                Text("Manage Favorites")
                    .font(.title2)
                    .padding()
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Label("Add", systemImage: "plus")
                }
                .padding()
            }
            
            List {
                ForEach(manager.favorites) { item in
                    HStack {
                        Image(systemName: "folder")
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.headline)
                            Text(item.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        // Explicit delete button for better macOS UX
                        Button {
                            manager.delete(id: item.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(BorderedButtonStyle())
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        manager.delete(id: manager.favorites[index].id)
                    }
                }
                .onMove { source, destination in
                    manager.move(from: source, to: destination)
                }
            }
            .frame(minWidth: 400, minHeight: 300)
            
            Text("Tip: You can drag to reorder favorites.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
        }
        // Basic Add Sheet for manual entry (optional, but good for completeness)
        .sheet(isPresented: $showingAddSheet) {
            ManualAddFavoriteView(onSave: { name, path in
                manager.add(name: name, path: path)
                showingAddSheet = false
            }, onCancel: {
                showingAddSheet = false
            })
        }
    }
}

struct ManualAddFavoriteView: View {
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    
    @State private var name: String = ""
    @State private var path: String = ""
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Favorite Manually")
                .font(.headline)
            
            TextField("Name", text: $name)
            TextField("Path", text: $path)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Add") {
                    if FavoritesManager.shared.contains(path: path) {
                         errorMessage = "This path is already in favorites."
                    } else if validatePath(path) {
                        onSave(name, path)
                    } else {
                        errorMessage = "Directory does not exist."
                    }
                }
                .disabled(name.isEmpty || path.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    private func validatePath(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }
}
