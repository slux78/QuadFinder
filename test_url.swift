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

let base = URL(fileURLWithPath: "/Users/user/Desktop")
let absoluteDest = "/System/Applications"
let relativeDest = "SubFolder"

let combinedAbsolute = base.appendingPathComponent(absoluteDest).path
let combinedRelative = base.appendingPathComponent(relativeDest).path

print("Base: \(base.path)")
print("Absolute Dest: \(absoluteDest)")
print("Combined Absolute: \(combinedAbsolute)") // if this is not /System/Applications, my logic was wrong.

print("Relative Dest: \(relativeDest)")
print("Combined Relative: \(combinedRelative)")
