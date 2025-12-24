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

struct FavoriteItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: String
    
    init(name: String, path: String) {
        self.id = UUID()
        self.name = name
        self.path = path
    }
}

@MainActor
class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published var favorites: [FavoriteItem] = [] {
        didSet {
            save()
        }
    }
    
    private let kFavoritesKey = "QuadFinder_Favorites"
    
    private init() {
        load()
    }
    
    func contains(path: String) -> Bool {
        return favorites.contains { $0.path == path }
    }
    
    @discardableResult
    func add(name: String, path: String) -> Bool {
        if contains(path: path) { return false }
        let newItem = FavoriteItem(name: name, path: path)
        favorites.append(newItem)
        return true
    }
    
    func update(item: FavoriteItem, newName: String, newPath: String) {
        if let index = favorites.firstIndex(where: { $0.id == item.id }) {
            var updated = item
            updated.name = newName
            updated.path = newPath
            favorites[index] = updated
        }
    }
    
    func delete(id: UUID) {
        favorites.removeAll { $0.id == id }
    }
    
    func move(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(favorites)
            UserDefaults.standard.set(data, forKey: kFavoritesKey)
        } catch {
            print("Failed to save favorites: \(error)")
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: kFavoritesKey) else { return }
        do {
            favorites = try JSONDecoder().decode([FavoriteItem].self, from: data)
        } catch {
            print("Failed to load favorites: \(error)")
        }
    }
}
