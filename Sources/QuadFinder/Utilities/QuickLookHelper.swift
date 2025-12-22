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
@preconcurrency import QuickLookUI

@MainActor
class QuickLookHelper: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookHelper()
    
    var currentURL: URL?
    
    private override init() {
        super.init()
    }
    
    func togglePreview(for url: URL?) {
        guard let panel = QLPreviewPanel.shared() else { return }
        
        if panel.isVisible {
            if currentURL == url || url == nil {
                // Close if same file or no file
                panel.close()
                currentURL = nil
            } else {
                // Switch file
                currentURL = url
                panel.reloadData()
            }
        } else {
            if let url = url {
                currentURL = url
                panel.dataSource = self
                panel.delegate = self
                panel.makeKeyAndOrderFront(nil)
                panel.reloadData()
            }
        }
    }
    
    // MARK: - QLPreviewPanelDataSource
    
    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated {
            return currentURL != nil ? 1 : 0
        }
    }
    
    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        MainActor.assumeIsolated {
            return currentURL as QLPreviewItem?
        }
    }
    
    // MARK: - QLPreviewPanelDelegate
    
    nonisolated func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        // Handle keyboard events if needed, or let default behavior pass
        return false
    }
}
