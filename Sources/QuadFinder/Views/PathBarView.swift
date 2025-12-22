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

struct PathBarView: View {
    @ObservedObject var state: PaneState
    
    var pathComponents: [URL] {
        var components: [URL] = []
        var current = state.currentPath
        
        // Loop upwards until we hit root
        while current.pathComponents.count > 1 {
            components.append(current)
            current = current.deletingLastPathComponent()
        }
        // Append root
        components.append(current) // Usually simple "/"
        
        return components.reversed()
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(pathComponents.enumerated()), id: \.offset) { index, url in
                    Button(action: {
                        state.navigateTo(url)
                    }) {
                        HStack(spacing: 4) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                            
                            Text(url.lastPathComponent == "/" ? "Macintosh HD" : url.lastPathComponent)
                                .font(.system(size: 11))
                                .foregroundColor(url == state.currentPath ? .primary : .secondary)
                                .fontWeight(url == state.currentPath ? .bold : .regular)
                            
                            if index < pathComponents.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8))
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.leading, 2)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .border(Color(nsColor: .separatorColor), width: 1)
    }
}
