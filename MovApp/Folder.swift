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
    
    var isFolder: Bool {
        if case .folder = self {
            return true
        }
        return false
    }
}
