import SwiftUI

struct Application: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let bundleIdentifier: String?

    // Cached icon for performance
    private var _icon: NSImage?

    var icon: NSImage {
        if let cached = _icon {
            return cached
        }

        // Get icon from NSWorkspace (fast, uses system cache)
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 64, height: 64)
        return icon
    }

    init(name: String, path: String, bundleIdentifier: String? = nil, icon: NSImage? = nil) {
        self.id = path
        self.name = name
        self.path = path
        self.bundleIdentifier = bundleIdentifier
        self._icon = icon
    }

    // Launch the application
    func launch() {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }

    // Hashable conformance (for Set/Dictionary)
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    static func == (lhs: Application, rhs: Application) -> Bool {
        lhs.path == rhs.path
    }
}
