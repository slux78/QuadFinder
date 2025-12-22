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

let fm = FileManager.default
let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)

let realDir = cwd.appendingPathComponent("RealDir")
let linkDir = cwd.appendingPathComponent("LinkDir")

do {
    // Cleanup
    if fm.fileExists(atPath: realDir.path) { try fm.removeItem(at: realDir) }
    if fm.fileExists(atPath: linkDir.path) { try fm.removeItem(at: linkDir) }

    // Setup
    try fm.createDirectory(at: realDir, withIntermediateDirectories: true)
    let fileInDir = realDir.appendingPathComponent("testfile.txt")
    try "content".write(to: fileInDir, atomically: true, encoding: .utf8)

    // Create Symlink: LinkDir -> RealDir
    try fm.createSymbolicLink(at: linkDir, withDestinationURL: realDir)

    print("Created structure:")
    print("  \(realDir.path)")
    print("  \(linkDir.path) -> \(realDir.path)")

    // Test 1: Check if LinkDir is directory (standard check)
    var isDir: ObjCBool = false
    let exists = fm.fileExists(atPath: linkDir.path, isDirectory: &isDir)
    print("Standard fileExists(isDir): exists=\(exists), isDir=\(isDir.boolValue)") 
    // Expect isDir=false because it is a symlink, even if it points to dir (usually)

    // Test 2: Resolve and check
    let destination = try fm.destinationOfSymbolicLink(atPath: linkDir.path)
    let destURL = linkDir.deletingLastPathComponent().appendingPathComponent(destination)
    var destIsDir: ObjCBool = false
    let destExists = fm.fileExists(atPath: destURL.path, isDirectory: &destIsDir)
    print("Resolved target exists: \(destExists), isDir=\(destIsDir.boolValue)")

    // Test 3: List contents of LinkDir
    print("Listing contents of \(linkDir.path)...")
    let contents = try fm.contentsOfDirectory(at: linkDir, includingPropertiesForKeys: [.isDirectoryKey], options: [])
    for url in contents {
        print("  Found: \(url.path)")
        let res = try url.resourceValues(forKeys: [.isDirectoryKey])
        print("    isDirectory: \(res.isDirectory ?? false)")
    }
    
    // Test 4: Access checks?
    print("Success listing contents via symlink.")

} catch {
    print("Error: \(error)")
}
