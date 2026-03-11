import SwiftUI
import Combine

enum SortOption: String, CaseIterable {
    case manual = "Manual (Custom Order)"
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case installDate = "Install Date (Newest Last)"
}

final class GridViewModel: ObservableObject {

    // MARK: - Scanner
    let scanner = ApplicationScanner()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - State
    @Published var gridItems: [GridItem] = []
    @Published var folders: [Folder] = []
    @Published var searchText: String = ""
    @Published var currentPageIndex: Int = 0
    @Published var isArrangeMode: Bool = false
    @Published var draggedItem: GridItem?
    @Published var openFolder: Folder?
    @Published var sortOption: SortOption = .manual
    @Published var isScrolling: Bool = false
    @Published var gridRows: Int = 4
    @Published var gridColumns: Int = 4

    private var scrollDebounceTask: Task<Void, Never>?
    private var saveDebounceTask: Task<Void, Never>?

    // MARK: - Persistence Model
    struct FolderData: Codable {
        let id: String
        let name: String
        let appPaths: [String]
    }

    init() {
        // Forward scanner updates so ContentView re-renders on isLoading changes
        scanner.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Computed Properties

    var filteredItems: [GridItem] {
        let filtered: [GridItem]
        if searchText.isEmpty {
            filtered = gridItems
        } else {
            filtered = gridItems.filter { item in
                switch item {
                case .app(let app):
                    return app.name.localizedCaseInsensitiveContains(searchText)
                case .folder(let folder):
                    return folder.name.localizedCaseInsensitiveContains(searchText) ||
                           folder.apps.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
                }
            }
        }
        return sortItems(filtered)
    }

    // MARK: - Layout

    func calculateRows(availableHeight: CGFloat) -> Int {
        max(1, Int(availableHeight / 180))
    }

    func calculateColumns(availableWidth: CGFloat) -> Int {
        max(1, Int(availableWidth / 180))
    }

    func calculatePageCount(totalItems: Int, rows: Int, cols: Int) -> Int {
        let itemsPerPage = max(1, rows * cols)
        return max(1, (totalItems + itemsPerPage - 1) / itemsPerPage)
    }

    func itemsForPage(_ pageIndex: Int, rows: Int, cols: Int) -> [GridItem] {
        let itemsPerPage = max(1, rows * cols)
        let startIndex = pageIndex * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, filteredItems.count)
        guard startIndex < filteredItems.count else { return [] }
        return Array(filteredItems[startIndex..<endIndex])
    }

    // MARK: - Sorting

    func sortItems(_ items: [GridItem]) -> [GridItem] {
        switch sortOption {
        case .manual:
            return items
        case .nameAsc:
            return items.sorted { itemName($0).localizedCompare(itemName($1)) == .orderedAscending }
        case .nameDesc:
            return items.sorted { itemName($0).localizedCompare(itemName($1)) == .orderedDescending }
        case .installDate:
            return items.sorted {
                (itemInstallDate($0) ?? .distantPast) < (itemInstallDate($1) ?? .distantPast)
            }
        }
    }

    private func itemName(_ item: GridItem) -> String {
        switch item {
        case .app(let app): return app.name
        case .folder(let folder): return folder.name
        }
    }

    private func itemInstallDate(_ item: GridItem) -> Date? {
        switch item {
        case .app(let app): return app.installDate
        case .folder(let folder): return folder.apps.compactMap { $0.installDate }.min()
        }
    }

    // MARK: - Persistence

    /// Loads saved state and applies both folders + gridItems in one pass.
    /// Calling this sets self.folders and self.gridItems together to avoid
    /// triggering multiple separate view update cycles.
    func loadOrderedItems() {
        let (newFolders, newItems) = buildLoadedState()
        self.folders = newFolders
        self.gridItems = newItems
    }

    private func buildLoadedState() -> (folders: [Folder], items: [GridItem]) {
        var loadedFolders: [Folder] = []
        if let data = UserDefaults.standard.data(forKey: "folders"),
           let decoded = try? JSONDecoder().decode([FolderData].self, from: data) {
            loadedFolders = decoded.map { fd in
                let apps = fd.appPaths.compactMap { path in
                    scanner.applications.first { $0.path == path }
                }
                return Folder(id: fd.id, name: fd.name, apps: apps)
            }
        }

        let appsInFolders = Set(loadedFolders.flatMap { $0.apps.map { $0.id } })
        let availableApps = scanner.applications.filter { !appsInFolders.contains($0.id) }

        var items: [GridItem] = availableApps.map { .app($0) }
        items.append(contentsOf: loadedFolders.map { .folder($0) })

        guard let savedOrder = UserDefaults.standard.array(forKey: "gridOrder") as? [String] else {
            return (loadedFolders, items)
        }

        var itemDict = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var ordered: [GridItem] = []
        for id in savedOrder {
            if let item = itemDict.removeValue(forKey: id) {
                ordered.append(item)
            }
        }
        ordered.append(contentsOf: itemDict.values)
        return (loadedFolders, ordered)
    }

    func saveGridOrder() {
        UserDefaults.standard.set(gridItems.map { $0.id }, forKey: "gridOrder")
        let folderData = folders.map {
            FolderData(id: $0.id, name: $0.name, appPaths: $0.apps.map { $0.path })
        }
        if let encoded = try? JSONEncoder().encode(folderData) {
            UserDefaults.standard.set(encoded, forKey: "folders")
        }
    }

    /// Debounced save — coalesces rapid successive calls (e.g. folders + gridItems
    /// both changing at once) into a single write after 100ms.
    func scheduleSave() {
        saveDebounceTask?.cancel()
        saveDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if !Task.isCancelled { saveGridOrder() }
        }
    }

    // MARK: - Scroll

    func handleScroll(deltaX: CGFloat, numPages: Int, safePageIndex: Int) {
        guard !isScrolling, abs(deltaX) > 10 else { return }

        let goRight = deltaX < 0 && safePageIndex < numPages - 1
        let goLeft  = deltaX > 0 && safePageIndex > 0
        guard goRight || goLeft else { return }

        isScrolling = true
        scrollDebounceTask?.cancel()

        withAnimation(.spring(response: 0.25, dampingFraction: 0.92)) {
            currentPageIndex = goRight ? safePageIndex + 1 : safePageIndex - 1
        }

        scrollDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            if !Task.isCancelled { isScrolling = false }
        }
    }

    // MARK: - Arrange Mode

    func exitArrangeMode() {
        withAnimation {
            isArrangeMode = false
            draggedItem = nil
        }
        saveGridOrder()
    }

    // MARK: - Lifecycle

    func initialize() async {
        await scanner.scanApplications()
        if gridItems.isEmpty {
            loadOrderedItems()
        }
    }

    func refreshIfNeeded() async {
        guard !isArrangeMode else { return }
        await scanner.scanApplications()
        loadOrderedItems()
    }
}
