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
    var favoritesWindow: NSWindow?
    
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
    
    func showManageFavoritesWindow() {
        if favoritesWindow == nil {
             let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            window.title = "Manage Favorites"
            window.center()
            window.contentView = NSHostingView(rootView: ManageFavoritesView())
            window.isReleasedWhenClosed = false
            favoritesWindow = window
        }
        favoritesWindow?.makeKeyAndOrderFront(nil)
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
            HelpItem(title: "New Folder", query: "create make new folder directory"),
            HelpItem(title: "Add to Favorites (Ctrl+D)", query: "bookmark favorite save directory"),
            HelpItem(title: "Go to Favorite (Ctrl+G)", query: "jump navigate bookmark favorite"),
            HelpItem(title: "Manage Favorites", query: "edit delete organize bookmarks favorites")
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
            HelpItem(title: "New Folder", query: "create make new folder directory"),
            HelpItem(title: "Add to Favorites (Ctrl+D)", query: "bookmark favorite save directory"),
            HelpItem(title: "Go to Favorite (Ctrl+G)", query: "jump navigate bookmark favorite"),
            HelpItem(title: "Manage Favorites", query: "edit delete organize bookmarks favorites")
        ]
        
        // ... filtering logic remains same ...
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
            // Check if it's the Manage Favorites item or just generic help
            // Ideally we'd differentiate, but for now showHelpWindow is the default action for help search items 
            // EXCEPT if we specifically matched "Manage Favorites" we could open that.
            // For simplicity in this task, let's keep it pointing to Help Window as per original design, 
            // OR we can try to be smart.
            // Given the Help items are just instructions, opening Help Window is correct.
            self.showHelpWindow()
        }
    }
}

extension Notification.Name {
    static let requestAddFavorite = Notification.Name("requestAddFavorite")
    static let requestGoFavorites = Notification.Name("requestGoFavorites")
    static let requestRenameTab = Notification.Name("requestRenameTab")
    static let requestNewFolder = Notification.Name("requestNewFolder")
}

@main
struct QuadFinderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandMenu("Favorites") {
                Button("Add to Favorites") {
                    NotificationCenter.default.post(name: .requestAddFavorite, object: nil)
                }
                .keyboardShortcut("d", modifiers: .control)
                
                Button("Go to Favorite...") {
                    NotificationCenter.default.post(name: .requestGoFavorites, object: nil)
                }
                .keyboardShortcut("g", modifiers: .control)
                
                Divider()
                
                Button("Manage Favorites...") {
                    appDelegate.showManageFavoritesWindow()
                }
            }
            CommandGroup(after: .newItem) {
                Button("New Folder") {
                    NotificationCenter.default.post(name: .requestNewFolder, object: NSApp.keyWindow)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Button("Rename Tab...") {
                    NotificationCenter.default.post(name: .requestRenameTab, object: NSApp.keyWindow)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .help) {
                Button("QuadFinder Help") {
                    appDelegate.showHelpWindow()
                }
            }
        }
    }
}
