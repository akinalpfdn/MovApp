# MovApp

due to the removal off Launchpad and new suck Apps dialog, a light weight launchpad alternative

![macOS](https://img.shields.io/badge/macOS-11.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## ✨ Features

- **iOS-Style Grid Layout** - Beautiful, responsive grid view with pagination
- **Smart Search** - Instantly find apps as you type
- **Drag & Drop Reordering** - Long-press to enter arrange mode, drag to reorganize
- **Complete Uninstall** - Remove apps and all related files (caches, preferences, containers)
- **Smooth Animations** - Native macOS animations with trackpad gestures
- **Lightweight** - Fast startup and minimal resource usage
- **Persistent Layout** - Remembers your app arrangement across launches

## 📸 Screenshots

### Grid View
![Grid View](screenshots/grid-view.png)

### Arrange Mode
![Arrange Mode](screenshots/arrange-view.png)

## 🚀 Installation

### Download

Download the latest release from the [Releases](../../releases) page.

1. Download `MovApp.dmg`
2. Open the DMG file
3. Drag **MovApp** to your Applications folder
4. Launch MovApp from Applications

### Build from Source

```bash
git clone https://github.com/YOUR_USERNAME/MovApp.git
cd MovApp
open MovApp.xcodeproj
```

Build and run using Xcode 15 or later.

## 🎯 Usage

### Basic Controls

- **Click** an app to launch it
- **Search** using the search bar at the top
- **Swipe** left/right with trackpad to navigate pages
- **Long-press** any app icon to enter arrange mode

### Arrange Mode

1. **Long-press** any app icon for 0.6 seconds
2. **Drag & drop** icons to reorder them
3. **Click the ❌** button to uninstall an app
4. Press **ESC** to exit arrange mode and save

### Uninstalling Apps

When you uninstall an app, MovApp removes:
- The application bundle
- Application Support files
- Caches
- Preferences
- Containers
- Group Containers
- Saved Application State

All files are moved to Trash (can be restored if needed).

## 🔧 Requirements

- macOS 11.0 or later
- Admin privileges (for complete app uninstallation)

## 🛠 Technical Details

Built with:
- **SwiftUI** for the native macOS interface
- **STPrivilegedTask** for secure admin operations
- **NSWorkspace** for fast app icon caching
- **UserDefaults** for persistent app ordering

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 🐛 Issues

Found a bug? Please open an issue on the [Issues](../../issues) page.

## 👨‍💻 Author

Created by Akinalp Fidan

---

**Note**: MovApp requires admin privileges to completely uninstall applications and their related files. This is necessary to remove files that are protected by macOS permissions.
