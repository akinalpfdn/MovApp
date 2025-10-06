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

    // Uninstall the application and related files
    func uninstall() -> Bool {
        let fileManager = FileManager.default
        var filesToDelete: [String] = []

        // 1. Add main app bundle
        filesToDelete.append(path)

        // 2. Find related files in common locations
        if let bundleId = bundleIdentifier {
            let homeDir = fileManager.homeDirectoryForCurrentUser.path

            // Application Support
            let appSupport = "\(homeDir)/Library/Application Support/\(bundleId)"
            if fileManager.fileExists(atPath: appSupport) {
                filesToDelete.append(appSupport)
            }

            // Caches
            let caches = "\(homeDir)/Library/Caches/\(bundleId)"
            if fileManager.fileExists(atPath: caches) {
                filesToDelete.append(caches)
            }

            // Preferences
            let prefs = "\(homeDir)/Library/Preferences/\(bundleId).plist"
            if fileManager.fileExists(atPath: prefs) {
                filesToDelete.append(prefs)
            }

            // Containers
            let containers = "\(homeDir)/Library/Containers/\(bundleId)"
            if fileManager.fileExists(atPath: containers) {
                filesToDelete.append(containers)
            }

            // Group Containers
            let groupContainers = "\(homeDir)/Library/Group Containers"
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: groupContainers)
                for item in contents {
                    if item.contains(bundleId) {
                        filesToDelete.append("\(groupContainers)/\(item)")
                    }
                }
            } catch {}

            // Saved Application State
            let savedState = "\(homeDir)/Library/Saved Application State/\(bundleId).savedState"
            if fileManager.fileExists(atPath: savedState) {
                filesToDelete.append(savedState)
            }
        }

        // Delete all found files
        var filesNeedingSudo: [String] = []
        var allSuccess = true

        for file in filesToDelete {
            do {
                try fileManager.trashItem(at: URL(fileURLWithPath: file), resultingItemURL: nil)
                print("Moved to trash: \(file)")
            } catch {
                print("Failed to delete without permissions: \(file)")
                filesNeedingSudo.append(file)
            }
        }

        // If some files need elevated permissions, use AppleScript with admin privileges
        if !filesNeedingSudo.isEmpty {
            return deleteWithAdminPrivileges(files: filesNeedingSudo)
        }

        return allSuccess
    }

    private func deleteWithAdminPrivileges(files: [String]) -> Bool {
        // Use STPrivilegedTask to delete files with admin privileges
        // Skip Containers folder - it's SIP protected and will clean itself

        let trashPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").path

        // Filter out Container files (SIP protected, can't be deleted)
        let deletableFiles = files.filter { !$0.contains("/Library/Containers/") }

        if deletableFiles.isEmpty {
            print("No files need admin deletion (all are Containers)")
            return true
        }

        // Build shell script to move all files in one command
        var moveCommands: [String] = []
        for file in deletableFiles {
            let fileName = (file as NSString).lastPathComponent
            moveCommands.append("mv '\(file)' '\(trashPath)/\(fileName)'")
        }

        let shellScript = moveCommands.joined(separator: " && ")

        print("Executing with admin privileges: \(shellScript)")

        let task = STPrivilegedTask()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", shellScript]

        let err = task.launch()
        if err != errAuthorizationSuccess {
            if err == errAuthorizationCanceled {
                print("User cancelled authentication")
                return false
            } else {
                print("Failed to authenticate: \(err)")
                return false
            }
        }

        task.waitUntilExit()

        if task.terminationStatus != 0 {
            if let output = task.outputFileHandle {
                let data = output.readDataToEndOfFile()
                if let errorMsg = String(data: data, encoding: .utf8) {
                    print("Error: \(errorMsg)")
                }
            }
            print("Failed to move files: status \(task.terminationStatus)")
            return false
        }

        print("Successfully moved all files to trash")
        return true
    }

    // Hashable conformance (for Set/Dictionary)
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    static func == (lhs: Application, rhs: Application) -> Bool {
        lhs.path == rhs.path
    }
}
