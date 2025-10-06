import Foundation
import Combine

class ApplicationScanner: ObservableObject {
    @Published var applications: [Application] = []
    @Published var isLoading = false

    private let applicationPaths = [
        "/Applications",
        "/System/Applications"
    ]

    // Scan for all applications
    func scanApplications() async {
        await MainActor.run {
            isLoading = true
        }

        // Scan in background thread
        let apps = await Task.detached(priority: .userInitiated) {
            var allApps: [Application] = []
            for path in self.applicationPaths {
                allApps.append(contentsOf: self.scanDirectory(path))
            }
            // Sort alphabetically
            return allApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }.value

        await MainActor.run {
            self.applications = apps
            self.isLoading = false
        }
    }

    // Scan a single directory for .app files
    nonisolated private func scanDirectory(_ path: String) -> [Application] {
        var apps: [Application] = []

        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return apps
        }

        for item in contents {
            guard item.hasSuffix(".app") else { continue }

            let fullPath = "\(path)/\(item)"
            let name = item.replacingOccurrences(of: ".app", with: "")

            // Get bundle identifier if available
            let bundleID = getBundleIdentifier(for: fullPath)

            apps.append(Application(
                name: name,
                path: fullPath,
                bundleIdentifier: bundleID
            ))
        }

        return apps
    }

    // Get bundle identifier from Info.plist
    nonisolated private func getBundleIdentifier(for appPath: String) -> String? {
        let infoPlistPath = "\(appPath)/Contents/Info.plist"

        guard FileManager.default.fileExists(atPath: infoPlistPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: infoPlistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }

        return plist["CFBundleIdentifier"] as? String
    }
}
