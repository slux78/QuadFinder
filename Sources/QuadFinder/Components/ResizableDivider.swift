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

struct ResizableDivider: View {
    enum Orientation {
        case horizontal // Dividing Left/Right
        case vertical   // Dividing Top/Bottom
    }
    
    @Binding var splitRatio: CGFloat
    let orientation: Orientation
    var onDoubleClick: (() -> Void)?
    
    @State private var currentDragInfo: (startRatio: CGFloat, startLocation: CGFloat)? = nil
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.1)) // Subtle hit area
                
                // Visible Line
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(
                        width: orientation == .horizontal ? 1 : nil,
                        height: orientation == .vertical ? 1 : nil
                    )
            }
        }
        .frame(
            width: orientation == .horizontal ? 8 : nil,
            height: orientation == .vertical ? 8 : nil
        )
        .contentShape(Rectangle())
        .onHover { inside in
            if inside {
                if orientation == .horizontal {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.resizeUpDown.push()
                }
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture(count: 2) {
            onDoubleClick?()
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    // We need context of the Container Size to calculate ratio delta.
                    // THIS IS TRICKY inside the Divider itself because it doesn't know the container size.
                    // Solution: We strictly need the container size passed in OR we use a different pattern.
                    //
                    // Better Pattern: The PARENT handles the DragGesture, or passes the container size proxy.
                    // However, standard ResizableDivider usage implies it handles the logic.
                    // Let's defer actual logic to the parent via a binding or closure?
                    //
                    // Or, simpler: We accept a `pixelsPerPoint` or `containerSize`.
                    // But `GeometryReader` inside Divider gives Divider size, not Parent.
                }
        )
    }
}

// Simplified handle that reports Drag Deltas to Parent
struct QuadResizeHandle: View {
    enum Orientation {
        case horizontal
        case vertical
    }
    
    let orientation: Orientation
    let onDrag: (CGFloat) -> Void // Delta
    let onReset: () -> Void
    
    @State private var previousTranslation: CGFloat = 0
    
    var body: some View {
        ZStack {
            Rectangle().fill(Color.clear)
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(
                    width: orientation == .horizontal ? 1 : nil,
                    height: orientation == .vertical ? 1 : nil
                )
        }
        .frame(
            width: orientation == .horizontal ? 8 : nil,
            height: orientation == .vertical ? 8 : nil
        )
        .contentShape(Rectangle())
        .onHover { inside in
            if inside {
                if orientation == .horizontal {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.resizeUpDown.push()
                }
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture(count: 2) {
            onReset()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let totalTranslation = orientation == .horizontal ? value.translation.width : value.translation.height
                    let delta = totalTranslation - previousTranslation
                    onDrag(delta)
                    previousTranslation = totalTranslation
                }
                .onEnded { _ in
                    previousTranslation = 0
                }
        )
    }
}

