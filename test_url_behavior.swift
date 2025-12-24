import Foundation

let u1 = URL(fileURLWithPath: "")
print("Empty path lastPathComponent: '\(u1.lastPathComponent)'")
print("Empty path absoluteString: '\(u1.absoluteString)'")
print("Empty path path: '\(u1.path)'")

let u2 = URL(fileURLWithPath: "/Users/slux78")
print("Home path lastPathComponent: '\(u2.lastPathComponent)'")
print("Home path path: '\(u2.path)'")
