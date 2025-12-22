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

import Foundation

/// Monitors a directory for changes (writes, attribute changes, etc.) using DispatchSource.
class DirectoryMonitor {
    private var monitorSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private let queue = DispatchQueue(label: "com.quadfinder.directorymonitor", attributes: .concurrent)

    /// Starts monitoring the given URL.
    /// - Parameters:
    ///   - url: The directory URL to monitor.
    ///   - handler: Closure called on the main thread when a change occurs.
    func startMonitoring(url: URL, handler: @escaping @Sendable () -> Void) {
        stopMonitoring() // specific cleanup before starting new
        
        // Open the directory
        let path = url.path
        fileDescriptor = open(path, O_EVTONLY)
        
        guard fileDescriptor != -1 else {
            print("DirectoryMonitor: Failed to open file descriptor for \(path)")
            return
        }
        
        // Create the source
        monitorSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .attrib, .link, .rename], // Monitor writes (content/downloads), attributes (metadata), file add/remove
            queue: queue
        )
        
        monitorSource?.setEventHandler {
            // Debounce or just fire?
            // For now, simple fire. The wrapper (PaneState) can debounce or throttle if needed.
            // Using slight delay to let file operations settle?
            print("DirectoryMonitor: Event detected in \(path)")
            DispatchQueue.main.async {
                handler()
            }
        }
        
        let fd = fileDescriptor
        monitorSource?.setCancelHandler {
            close(fd)
        }
        
        monitorSource?.resume()
    }
    
    /// Stops the current monitor.
    func stopMonitoring() {
        monitorSource?.cancel()
        // fileDescriptor closed in cancel handler
        monitorSource = nil
    }
    
    deinit {
        stopMonitoring()
    }
}
