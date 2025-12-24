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

struct AddFavoriteView: View {
    let initialPath: String
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    
    @State private var name: String = ""
    @State private var path: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add to Favorites")
                .font(.headline)
            
            VStack(alignment: .leading) {
                Text("Name:")
                TextField("Favorite Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Path:")
                Text(path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                
                if FavoritesManager.shared.contains(path: path) {
                    Text("Already in favorites")
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button("OK") {
                    if FavoritesManager.shared.contains(path: path) {
                         // Show error or just close? 
                         // For now, let's treat duplicate as "already done" so just close,
                         // OR show alert. Given simple UI, maybe change button text or disable?
                         // Let's rely on Manager return value but for better UX, check state.
                         onCancel() // If already there, just close acting like it worked or was cancelled
                    } else {
                        onSave(name, path)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || FavoritesManager.shared.contains(path: path)) // Disable if already exists
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            self.name = URL(fileURLWithPath: initialPath).lastPathComponent
            self.path = initialPath
        }
    }
}
