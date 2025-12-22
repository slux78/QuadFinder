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

struct FileInfoView: View {
    let item: FileItem
    @Binding var isPresented: Bool
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()
    
    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Icon + Name
            HStack(spacing: 12) {
                item.icon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(item.kind)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let size = item.size {
                        Text(byteFormatter.string(fromByteCount: size))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("--")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.bottom, 8)
            
            Divider()
            
            // General Info
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Kind:", value: item.kind)
                if let size = item.size {
                    InfoRow(label: "Size:", value: byteFormatter.string(fromByteCount: size))
                }
                InfoRow(label: "Where:", value: item.url.path)
            }
            
            Divider()
            
            // Dates
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Created:", value: dateFormatter.string(from: item.dateCreated))
                InfoRow(label: "Modified:", value: dateFormatter.string(from: item.dateModified))
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Close") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 350, minHeight: 400)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .bold()
                .frame(width: 70, alignment: .trailing)
                .foregroundColor(.secondary)
            Text(value)
                .lineLimit(3)
                .textSelection(.enabled)
        }
    }
}
