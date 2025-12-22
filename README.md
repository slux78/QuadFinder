# QuadFinder

**QuadFinder** is a powerful, native macOS file manager designed for multitasking. It features a unique four-pane layout that allows you to manage files across multiple directories simultaneously with ease. Built with Swift, SwiftUI, and AppKit.

## Key Features

-   **4-Pane Layout**: View and interact with four different directories at once.
-   **Maximize Pane**: Focus on a single task by maximizing any pane to full screen (`Ctrl + Shift + Enter`). Toggle back instantly.
-   **Drag & Drop**: Seamlessly move or copy files between panes.
-   **Smart Search**: Integrated file search within each pane (`Cmd + F`).
-   **Native Experience**: Supports standard macOS features like Quick Look (`Space`), Get Info (`Cmd + I`), and Context Menus.
-   **Help & Discovery**: Built-in Help window with a searchable list of features and shortcuts.

## Keyboard Shortcuts

| Action | Shortcut |
| :--- | :--- |
| **Maximize / Restore Pane** | `Ctrl` + `Shift` + `Enter` |
| **Find / Search** | `Cmd` + `F` |
| **Get Info** | `Cmd` + `I` |
| **Quick Look** | `Space` |
| **Copy** | `Cmd` + `C` |
| **Paste** | `Cmd` + `V` |
| **New Folder** | Right Click -> New Folder |
| **Rename** | Click Name or Right Click |
| **Open Help** | `Help` -> `QuadFinder Help` |

## Building the App

QuadFinder uses a custom build script to package the application bundle.

1.  Open Terminal in the project directory.
2.  Run the build script:

```bash
./bundle_app.sh
```

This will compile the project in Release mode and create `QuadFinder.app` in the current directory.

## License

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for details.

---
*Copyright (C) 2025 QuadFinder*
