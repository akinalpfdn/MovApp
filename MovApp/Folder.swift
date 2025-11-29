import SwiftUI

struct Folder: Identifiable, Hashable {
    let id: String
    var name: String
    var apps: [Application]

    init(id: String = UUID().uuidString, name: String, apps: [Application]) {
        self.id = id
        self.name = name
        self.apps = apps
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Folder, rhs: Folder) -> Bool {
        lhs.id == rhs.id
    }
}

// Item type that can be either an app or a folder
enum GridItem: Identifiable, Hashable {
    case app(Application)
    case folder(Folder)

    var id: String {
        switch self {
        case .app(let app):
            return app.id
        case .folder(let folder):
            return folder.id
        }
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: GridItem, rhs: GridItem) -> Bool {
        lhs.id == rhs.id
    }
}
