//
//  ContentView.swift
//  MovApp
//
//  Created by Akinalp Fidan on 6.10.2025.
//

import SwiftUI
import UniformTypeIdentifiers

extension FileManager {
    func allocatedSizeOfDirectory(at url: URL) throws -> Int64 {
        guard let enumerator = self.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey]),
                  let size = resourceValues.totalFileAllocatedSize else {
                continue
            }
            totalSize += Int64(size)
        }
        return totalSize
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct GridItemButton: View {
    let item: GridItem
    @Binding var isArrangeMode: Bool
    @Binding var draggedItem: GridItem?
    @Binding var gridItems: [GridItem]
    @Binding var folders: [Folder]
    @Binding var openFolder: Folder?
    let filteredItems: [GridItem]

    @State private var wiggleRotation: Double = 0
    @State private var showDeleteConfirmation = false
    @State private var isHoveringOver = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Display app or folder
            Group {
                switch item {
                case .app(let app):
                    AppIconView(app: app)
                case .folder(let folder):
                    FolderIconView(folder: folder)
                }
            }
            .opacity(draggedItem?.id == item.id && isArrangeMode ? 0.5 : 1.0)
            .rotationEffect(.degrees(wiggleRotation))
            .scaleEffect(isHoveringOver ? 1.1 : 1.0)
            .onTapGesture {
                if !isArrangeMode {
                    handleTap()
                }
            }
            .onLongPressGesture(minimumDuration: 0.6) {
                if !isArrangeMode {
                    withAnimation {
                        isArrangeMode = true
                        if gridItems.isEmpty {
                            gridItems = filteredItems
                        }
                    }
                }
            }

            // Delete button in arrange mode
            if isArrangeMode {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white, .red)
                        .shadow(radius: 2)
                }
                .buttonStyle(.plain)
                .offset(x: -4, y: -4)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .alert(getItemName(), isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button(item.isFolder ? "Delete Folder" : "Move to Trash", role: .destructive) {
                handleDelete()
            }
        } message: {
            Text(getDeleteMessage())
        }
        .onDrag {
            if isArrangeMode {
                draggedItem = item
                return NSItemProvider(object: item.id as NSString)
            }
            return NSItemProvider()
        }
        .onDrop(of: [.text], delegate: GridItemDropDelegate(
            item: item,
            items: $gridItems,
            folders: $folders,
            draggedItem: $draggedItem
        ))
        .onChange(of: isArrangeMode) { _, newValue in
            if newValue {
                startWiggle()
            } else {
                wiggleRotation = 0
            }
        }
    }

    func handleTap() {
        switch item {
        case .app(let app):
            app.launch()
        case .folder(let folder):
            openFolder = folder
        }
    }

    func getItemName() -> String {
        switch item {
        case .app(let app):
            return "Uninstall \(app.name)?"
        case .folder(let folder):
            return "Delete \(folder.name)?"
        }
    }

    func getDeleteMessage() -> String {
        switch item {
        case .app(let app):
            return "This will move \(app.name) and its related files to the Trash."
        case .folder:
            return "This will delete the folder. Apps will be moved back to the main grid."
        }
    }

    func handleDelete() {
        switch item {
        case .app(let app):
            let success = app.uninstall()
            if success {
                withAnimation {
                    if let index = gridItems.firstIndex(where: { $0.id == item.id }) {
                        gridItems.remove(at: index)
                    }
                }
            }
        case .folder(let folder):
            withAnimation {
                // Remove folder from grid
                if let index = gridItems.firstIndex(where: { $0.id == item.id }) {
                    gridItems.remove(at: index)
                }
                // Remove from folders array
                if let folderIndex = folders.firstIndex(where: { $0.id == folder.id }) {
                    folders.remove(at: folderIndex)
                }
                // Add apps back to grid
                for app in folder.apps {
                    gridItems.append(.app(app))
                }
            }
        }
    }

    func startWiggle() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if !isArrangeMode {
                timer.invalidate()
                wiggleRotation = 0
            } else {
                withAnimation(.easeInOut(duration: 0.1)) {
                    wiggleRotation = Double.random(in: -3...3)
                }
            }
        }
    }
}



struct GridItemDropDelegate: DropDelegate {
    let item: GridItem
    @Binding var items: [GridItem]
    @Binding var folders: [Folder]
    @Binding var draggedItem: GridItem?

    func performDrop(info: DropInfo) -> Bool {
        // Check if dropping app on app to create folder
        if let dragged = draggedItem,
           case .app(let draggedApp) = dragged,
           case .app(let targetApp) = item,
           draggedApp.id != targetApp.id {
            createFolder(draggedApp: draggedApp, targetApp: targetApp)
            draggedItem = nil
            return true
        }

        // Check if dropping app on folder to add to folder
        if let dragged = draggedItem,
           case .app(let draggedApp) = dragged,
           case .folder(var targetFolder) = item {
            addAppToFolder(app: draggedApp, folder: &targetFolder)
            draggedItem = nil
            return true
        }

        draggedItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              let fromIndex = items.firstIndex(where: { $0.id == draggedItem.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }),
              fromIndex != toIndex else { return }

        // Only reorder if not creating folder
        if !shouldCreateFolder() {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }

    func shouldCreateFolder() -> Bool {
        guard let dragged = draggedItem else { return false }
        if case .app = dragged, case .app = item {
            return true
        }
        return false
    }

    func createFolder(draggedApp: Application, targetApp: Application) {
        withAnimation {
            // Find target app's position to preserve it
            guard let targetIndex = items.firstIndex(where: { item in
                if case .app(let app) = item {
                    return app.id == targetApp.id
                }
                return false
            }) else { return }

            // Remove both apps from items
            items.removeAll { item in
                if case .app(let app) = item {
                    return app.id == draggedApp.id || app.id == targetApp.id
                }
                return false
            }

            // Create new folder at target app's position
            let newFolder = Folder(
                name: "Folder",
                apps: [targetApp, draggedApp]
            )
            folders.append(newFolder)

            // Insert folder at the original position of target app
            let insertIndex = min(targetIndex, items.count)
            items.insert(.folder(newFolder), at: insertIndex)
        }
    }

    func addAppToFolder(app: Application, folder: inout Folder) {
        withAnimation {
            // Remove app from items
            items.removeAll { item in
                if case .app(let a) = item {
                    return a.id == app.id
                }
                return false
            }

            // Add app to folder
            folder.apps.append(app)

            // Update folder in folders array
            if let folderIndex = folders.firstIndex(where: { $0.id == folder.id }) {
                folders[folderIndex] = folder
            }

            // Update folder in items array
            if let itemIndex = items.firstIndex(where: { $0.id == folder.id }) {
                items[itemIndex] = .folder(folder)
            }
        }
    }
}

struct ScrollWheelHandler: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ScrollWheelView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let scrollView = nsView as? ScrollWheelView {
            scrollView.onScroll = onScroll
        }
    }

    class ScrollWheelView: NSView {
        var onScroll: ((CGFloat) -> Void)?

        override func scrollWheel(with event: NSEvent) {
            onScroll?(event.scrollingDeltaX)
        }
    }
}

enum SortOption: String, CaseIterable {
    case manual = "Manual (Custom Order)"
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case installDate = "Install Date (Newest Last)"
}

struct ContentView: View {
    @StateObject private var scanner = ApplicationScanner()
    @State private var searchText = ""
    @State private var window: NSWindow?
    @State private var currentPageIndex = 0
    @State private var isScrolling = false
    @State private var scrollDebounceTask: Task<Void, Never>?
    @State private var isArrangeMode = false
    @State private var draggedItem: GridItem?
    @State private var gridItems: [GridItem] = []
    @State private var folders: [Folder] = []
    @State private var sortOption: SortOption = .manual
    @State private var openFolder: Folder?
    
    // Calculate number of rows that fit in screen
    private var rows: Int {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 900
        let availableHeight = screenHeight - 100 // minus search bar
        let rowHeight: CGFloat = 180 // icon (150) + spacing (30)
        return max(4, Int(availableHeight / rowHeight))
    }
    
    private var columns: Int {
        let screenWidth = NSScreen.main?.visibleFrame.width ?? 1200
        let availableWidth = screenWidth - 60 // padding
        let columnWidth: CGFloat = 180 // icon (150) + spacing (30)
        return max(4, Int(availableWidth / columnWidth))
    }
    
    var filteredItems: [GridItem] {
        // Filter by search
        let filtered = searchText.isEmpty ? gridItems : gridItems.filter { item in
            switch item {
            case .app(let app):
                return app.name.localizedCaseInsensitiveContains(searchText)
            case .folder(let folder):
                return folder.name.localizedCaseInsensitiveContains(searchText) ||
                       folder.apps.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }

        // Sort
        let sorted = sortItems(filtered)

        return sorted
    }

    func sortItems(_ items: [GridItem]) -> [GridItem] {
        switch sortOption {
        case .manual:
            return items
        case .nameAsc:
            return items.sorted { getName($0).localizedCompare(getName($1)) == .orderedAscending }
        case .nameDesc:
            return items.sorted { getName($0).localizedCompare(getName($1)) == .orderedDescending }
        case .installDate:
            return items.sorted { item1, item2 in
                let date1 = getInstallDate(item1) ?? Date.distantPast
                let date2 = getInstallDate(item2) ?? Date.distantPast
                return date1.compare(date2) == .orderedAscending
            }
        }
    }

    func getInstallDate(_ item: GridItem) -> Date? {
        switch item {
        case .app(let app):
            return app.installDate
        case .folder(let folder):
            // For folders, use the oldest install date of their apps
            return folder.apps.compactMap { $0.installDate }.min()
        }
    }

    func getName(_ item: GridItem) -> String {
        switch item {
        case .app(let app):
            return app.name
        case .folder(let folder):
            return folder.name
        }
    }

    // Load saved items (apps + folders)
    func loadOrderedItems() -> [GridItem] {
        // Load folders
        if let foldersData = UserDefaults.standard.data(forKey: "folders"),
           let loadedFolders = try? JSONDecoder().decode([FolderData].self, from: foldersData) {
            folders = loadedFolders.map { data in
                let apps = data.appPaths.compactMap { path in
                    scanner.applications.first { $0.path == path }
                }
                return Folder(id: data.id, name: data.name, apps: apps)
            }
        }

        // Get apps not in folders
        let appsInFolders = Set(folders.flatMap { $0.apps.map { $0.id } })
        let availableApps = scanner.applications.filter { !appsInFolders.contains($0.id) }

        // Create grid items
        var items: [GridItem] = availableApps.map { .app($0) }
        items.append(contentsOf: folders.map { .folder($0) })

        // Load saved order
        if let savedOrder = UserDefaults.standard.array(forKey: "gridOrder") as? [String] {
            var itemDict: [String: GridItem] = [:]
            for item in items {
                itemDict[item.id] = item
            }

            var ordered: [GridItem] = []
            for id in savedOrder {
                if let item = itemDict[id] {
                    ordered.append(item)
                    itemDict.removeValue(forKey: id)
                }
            }

            // Add new items at the end
            ordered.append(contentsOf: itemDict.values)
            return ordered
        }

        return items
    }

    struct FolderData: Codable {
        let id: String
        let name: String
        let appPaths: [String]
    }

    // Save grid order and folders
    func saveGridOrder() {
        // Save item order
        let order = gridItems.map { $0.id }
        UserDefaults.standard.set(order, forKey: "gridOrder")

        // Save folders
        let folderData = folders.map { folder in
            FolderData(
                id: folder.id,
                name: folder.name,
                appPaths: folder.apps.map { $0.path }
            )
        }
        if let encoded = try? JSONEncoder().encode(folderData) {
            UserDefaults.standard.set(encoded, forKey: "folders")
        }

        print("Saved grid order: \(order.count) items, \(folders.count) folders")
    }

    // Split items into pages
    func itemsForPage(_ pageIndex: Int) -> [GridItem] {
        let itemsPerPage = rows * columns
        let startIndex = pageIndex * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, filteredItems.count)

        guard startIndex < filteredItems.count else { return [] }
        return Array(filteredItems[startIndex..<endIndex])
    }

    func numberOfPages() -> Int {
        let itemsPerPage = rows * columns
        return max(1, (filteredItems.count + itemsPerPage - 1) / itemsPerPage)
    }
    
    var body: some View {
   
            VStack(spacing: 0) {
                // Search and Sort bar
                HStack(spacing: 12) {
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.6))

                        TextField("Search applications...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .onChange(of: searchText) { _, _ in
                                currentPageIndex = 0
                            }
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)

                    // Sort dropdown
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(action: {
                                sortOption = option
                                currentPageIndex = 0
                            }) {
                                HStack {
                                    Text(option.rawValue)
                                    if sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 14))
                            Text("Sort")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(.horizontal)
                .padding(.top)
            
            // App grid
            if scanner.isLoading {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Spacer()
            } else {
                GeometryReader { geometry in
                    let pageWidth = geometry.size.width
                    let totalOffset = -CGFloat(currentPageIndex) * pageWidth

                    ScrollViewReader { proxy in
                        HStack(spacing: 0) {
                            ForEach(0..<numberOfPages(), id: \.self) { pageIndex in
                                LazyVGrid(
                                    columns: Array(repeating: SwiftUI.GridItem(.fixed(150), spacing: 30), count: columns),
                                    spacing: 30
                                ) {
                                    ForEach(itemsForPage(pageIndex)) { item in
                                        GridItemButton(
                                            item: item,
                                            isArrangeMode: $isArrangeMode,
                                            draggedItem: $draggedItem,
                                            gridItems: $gridItems,
                                            folders: $folders,
                                            openFolder: $openFolder,
                                            filteredItems: filteredItems
                                        )
                                    }
                                }
                                .frame(width: pageWidth)
                                .id(pageIndex)
                            }
                        }
                        .offset(x: totalOffset)
                        .background(
                            Color.clear
                                .onTapGesture {
                                    if isArrangeMode {
                                        withAnimation {
                                            isArrangeMode = false
                                            draggedItem = nil
                                        }
                                        saveGridOrder()
                                    }
                                }
                        )
                        .background(
                            ScrollWheelHandler { deltaX in
                                // Ignore if already processing a scroll
                                guard !isScrolling else { return }

                                let threshold: CGFloat = 10

                                // Only respond to significant scroll
                                guard abs(deltaX) > threshold else { return }

                                // Determine direction
                                let scrollRight = deltaX < 0
                                let scrollLeft = deltaX > 0

                                // Check if we can move in that direction
                                let canScrollRight = scrollRight && currentPageIndex < numberOfPages() - 1
                                let canScrollLeft = scrollLeft && currentPageIndex > 0

                                guard canScrollRight || canScrollLeft else { return }

                                // Set scrolling flag
                                isScrolling = true

                                // Cancel existing debounce task
                                scrollDebounceTask?.cancel()

                                // Change page
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.92)) {
                                    if canScrollRight {
                                        currentPageIndex += 1
                                    } else if canScrollLeft {
                                        currentPageIndex -= 1
                                    }
                                }

                                // Reset scrolling flag after animation + cooldown
                                scrollDebounceTask = Task {
                                    try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
                                    if !Task.isCancelled {
                                        isScrolling = false
                                    }
                                }
                            }
                        )
                    }
                }

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<numberOfPages(), id: \.self) { index in
                        Circle()
                            .fill(index == currentPageIndex ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    currentPageIndex = index
                                }
                            }
                    }
                }
                .padding(.bottom, 20)
            }
            }.background(.ultraThinMaterial)
            .onKeyPress(.escape) {
                if isArrangeMode {
                    withAnimation {
                        isArrangeMode = false
                        draggedItem = nil
                    }
                    saveGridOrder()
                    return .handled
                }
                return .ignored
            }
            .sheet(item: $openFolder) { folder in
                FolderSheetView(
                    folder: folder,
                    folderName: Binding(
                        get: {
                            if let folderIndex = folders.firstIndex(where: { $0.id == folder.id }) {
                                return folders[folderIndex].name
                            }
                            return folder.name
                        },
                        set: { newName in
                            if let folderIndex = folders.firstIndex(where: { $0.id == folder.id }) {
                                folders[folderIndex].name = newName
                                if let itemIndex = gridItems.firstIndex(where: { $0.id == folder.id }) {
                                    gridItems[itemIndex] = .folder(folders[folderIndex])
                                }
                                // Also update the openFolder state to keep the sheet consistent
                                if openFolder?.id == folder.id {
                                    openFolder?.name = newName
                                }
                                saveGridOrder()
                            }
                        }
                    ),
                    isPresented: Binding(
                        get: { openFolder != nil },
                        set: { if !$0 { openFolder = nil } }
                    ),
                    onRemoveApp: { appToRemove in
                        withAnimation {
                            // Remove app from folder
                            if let folderIndex = folders.firstIndex(where: { $0.id == folder.id }) {
                                folders[folderIndex].apps.removeAll { $0.id == appToRemove.id }

                                // If folder is empty, delete it
                                if folders[folderIndex].apps.isEmpty {
                                    folders.remove(at: folderIndex)
                                    gridItems.removeAll { item in
                                        if case .folder(let f) = item {
                                            return f.id == folder.id
                                        }
                                        return false
                                    }
                                    openFolder = nil
                                } else {
                                    // Update folder in grid
                                    if let itemIndex = gridItems.firstIndex(where: { $0.id == folder.id }) {
                                        gridItems[itemIndex] = .folder(folders[folderIndex])
                                    }
                                    // Refresh the sheet with updated folder
                                    openFolder = folders[folderIndex]
                                }
                            }

                            // Add app back to grid
                            gridItems.append(.app(appToRemove))
                            saveGridOrder()
                        }
                    },
                    onRenameFolder: { newName in
                        saveGridOrder()
                    },
                    onReorderApps: { reorderedApps in
                        if let folderIndex = folders.firstIndex(where: { $0.id == folder.id }) {
                            folders[folderIndex].apps = reorderedApps
                            if let itemIndex = gridItems.firstIndex(where: { $0.id == folder.id }) {
                                gridItems[itemIndex] = .folder(folders[folderIndex])
                            }
                            saveGridOrder()
                        }
                    }
                )
            }

        .task {
            await scanner.scanApplications()
            // Load items after scanning is complete
            if gridItems.isEmpty {
                gridItems = loadOrderedItems()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await scanner.scanApplications()
                gridItems = loadOrderedItems()
            }
        }
        .onChange(of: gridItems) { oldValue, newValue in
            // Save whenever items are reordered or deleted
            if !newValue.isEmpty && oldValue != newValue {
                saveGridOrder()
            }
        }
        .onChange(of: folders) { oldValue, newValue in
            // Save whenever folders change
            if oldValue != newValue {
                saveGridOrder()
            }
        }
    }
    
    
}
