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

struct FileListView: NSViewControllerRepresentable {
    @ObservedObject var state: PaneState
    var onFocus: () -> Void
    
    func makeNSViewController(context: Context) -> FileListViewController {
        let vc = FileListViewController()
        vc.paneState = state
        vc.onFocus = onFocus
        return vc
    }
    
    func updateNSViewController(_ nsViewController: FileListViewController, context: Context) {
        nsViewController.paneState = state // Ensure state is updated
        nsViewController.onFocus = onFocus
        nsViewController.update(with: state)
    }
}
