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
import AppKit

struct WindowAccessor: NSViewRepresentable {
    // Shared state to track the last active window size
    static var standardWindowSize: CGSize?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                // Set delegate to track resizing
                window.delegate = context.coordinator
                
                // 1. Apply shared size if available
                if let size = WindowAccessor.standardWindowSize {
                    var frame = window.frame
                    frame.size = size
                    window.setFrame(frame, display: true)
                } else {
                    // First window sets the standard
                    WindowAccessor.standardWindowSize = window.frame.size
                }
                
                // 2. Off-screen protection
                Self.ensureVisible(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
    
    static func ensureVisible(_ window: NSWindow) {
        if let screen = window.screen {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            
            // Top-Left corner is critical for window management (title bar)
            let topLeft = CGPoint(x: windowFrame.minX, y: windowFrame.maxY)
            
            if !screenFrame.contains(topLeft) {
                // If top-left is off-screen, center on main screen
                centerOnMain(window)
            }
        } else {
            // No screen detected? Center on main.
            centerOnMain(window)
        }
    }
    
    static func centerOnMain(_ window: NSWindow) {
        if let mainScreen = NSScreen.main {
            let mainFrame = mainScreen.visibleFrame
            let windowFrame = window.frame
            let newX = mainFrame.midX - (windowFrame.width / 2)
            let newY = mainFrame.midY - (windowFrame.height / 2)
            window.setFrameOrigin(NSPoint(x: newX, y: newY))
        }
    }

    class Coordinator: NSObject, NSWindowDelegate {
        func windowDidResize(_ notification: Notification) {
            if let window = notification.object as? NSWindow {
                // Update shared state on resize
                WindowAccessor.standardWindowSize = window.frame.size
            }
        }
    }
}
