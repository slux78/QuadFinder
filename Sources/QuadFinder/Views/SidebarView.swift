/*
    QuadFinder
    Copyright (C) 2025 QuadFinder

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

import SwiftUI
import Combine

struct SidebarView: View {
    @Binding var activePaneId: UUID?
    var onNavigate: (URL) -> Void
    
    @StateObject private var volumeMonitor = VolumeMonitor()
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    
    var body: some View {
        List {
            Section(header: Text("Favorites")) {
                ForEach(favoritesManager.favorites) { favorite in
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(favorite.name)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onNavigate(URL(fileURLWithPath: favorite.path))
                    }
                }
            }
            
            Section(header: Text("Locations")) {
                ForEach(volumeMonitor.volumes) { volume in
                    HStack {
                        Image(nsImage: volume.icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text(volume.name)
                            .lineLimit(1)
                        Spacer()
                        
                        if volume.isRemovable {
                            Button(action: {
                                volumeMonitor.unmount(volume)
                            }) {
                                Image(systemName: "eject.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onNavigate(volume.url)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.sidebar)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct VolumeItem: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let icon: NSImage
    let isRemovable: Bool
}

@MainActor
class VolumeMonitor: ObservableObject {
    @Published var volumes: [VolumeItem] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        refreshVolumes()
        
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)
            .sink { [weak self] _ in self?.refreshVolumes() }
            .store(in: &cancellables)
            
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)
            .sink { [weak self] _ in self?.refreshVolumes() }
            .store(in: &cancellables)
    }
    
    func refreshVolumes() {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey, .volumeIsInternalKey]
        let options: FileManager.VolumeEnumerationOptions = [.skipHiddenVolumes]
        
        var newVolumes: [VolumeItem] = []
        
        if let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: options) {
            for url in urls {
                guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
                
                let name = values.volumeName ?? url.lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                let isRemovable = values.volumeIsRemovable == true || values.volumeIsEjectable == true
                
                newVolumes.append(VolumeItem(name: name, url: url, icon: icon, isRemovable: isRemovable))
            }
        }
        
        self.volumes = newVolumes
    }
    
    func unmount(_ volume: VolumeItem) {
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: volume.url)
        } catch {
            print("Failed to unmount \(volume.name): \(error)")
        }
    }
}
