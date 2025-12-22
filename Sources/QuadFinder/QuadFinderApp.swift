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

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app runs as a regular app with Dock icon and UI
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
        
        // Register Help Search Handler
        NSApp.registerUserInterfaceItemSearchHandler(self)
    }
    
    var helpWindow: NSWindow?
    
    func showHelpWindow() {
        if helpWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            window.title = "QuadFinder Help"
            window.center()
            window.contentView = NSHostingView(rootView: HelpView())
            window.isReleasedWhenClosed = false
            helpWindow = window
        }
        
        helpWindow?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Help Search Handler
extension AppDelegate: NSUserInterfaceItemSearching {
    
    struct HelpItem {
        let title: String
        let query: String
    }
    
    private var helpItems: [HelpItem] {
        [
            HelpItem(title: "Maximize Pane (Ctrl+Shift+Enter)", query: "maximize pane full screen toggle layout"),
            HelpItem(title: "Drag and Drop Files", query: "drag drop move copy files"),
            HelpItem(title: "Search / Find Files (Cmd+F)", query: "search find filter string"),
            HelpItem(title: "Quick Look (Space)", query: "quick look preview space"),
            HelpItem(title: "Get Info (Cmd+I)", query: "get info details properties"),
            HelpItem(title: "QuadFinder Shortcuts", query: "shortcuts keys keyboard help"),
            HelpItem(title: "New Folder", query: "create make new folder directory")
        ]
    }

    nonisolated func searchForItems(withSearch searchString: String, resultLimit: Int, matchedItemHandler: @escaping ([Any]) -> Void) {
        let normalizedQuery = searchString.lowercased()
        
        let items = [
            HelpItem(title: "Maximize Pane (Ctrl+Shift+Enter)", query: "maximize pane full screen toggle layout"),
            HelpItem(title: "Drag and Drop Files", query: "drag drop move copy files"),
            HelpItem(title: "Search / Find Files (Cmd+F)", query: "search find filter string"),
            HelpItem(title: "Quick Look (Space)", query: "quick look preview space"),
            HelpItem(title: "Get Info (Cmd+I)", query: "get info details properties"),
            HelpItem(title: "QuadFinder Shortcuts", query: "shortcuts keys keyboard help"),
            HelpItem(title: "New Folder", query: "create make new folder directory")
        ]
        
        let results = items.filter { item in
            item.title.localizedCaseInsensitiveContains(normalizedQuery) ||
            item.query.localizedCaseInsensitiveContains(normalizedQuery)
        }
        
        matchedItemHandler(Array(results.prefix(resultLimit)))
    }
    
    nonisolated func localizedTitles(forItem item: Any) -> [String] {
        guard let helpItem = item as? HelpItem else { return [] }
        return [helpItem.title]
    }
    
    nonisolated func performAction(forItem item: Any) {
        Task { @MainActor in
            self.showHelpWindow()
        }
    }
}

@main
struct QuadFinderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("QuadFinder Help") {
                    appDelegate.showHelpWindow()
                }
            }
        }
    }
}
