import SwiftUI

struct ContentView: View {
    @StateObject private var vm = GridViewModel()

    var body: some View {
        VStack(spacing: 0) {
            searchSortBar

            if vm.scanner.isLoading {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Spacer()
            } else {
                appGrid
            }

            pageIndicators
        }
        .background(.ultraThinMaterial)
        .onKeyPress(.escape) {
            if vm.isArrangeMode { vm.exitArrangeMode(); return .handled }
            if vm.selectedIndex != nil { vm.clearSelection(); return .handled }
            return .ignored
        }
        .onKeyPress(.upArrow)    { guard !vm.isArrangeMode else { return .ignored }; vm.moveSelection(.up);    return .handled }
        .onKeyPress(.downArrow)  { guard !vm.isArrangeMode else { return .ignored }; vm.moveSelection(.down);  return .handled }
        .onKeyPress(.leftArrow)  { guard !vm.isArrangeMode else { return .ignored }; vm.moveSelection(.left);  return .handled }
        .onKeyPress(.rightArrow) { guard !vm.isArrangeMode else { return .ignored }; vm.moveSelection(.right); return .handled }
        .onKeyPress(.return)     { guard !vm.isArrangeMode, vm.selectedIndex != nil else { return .ignored }; vm.activateSelected(); return .handled }
        .sheet(item: $vm.openFolder) { folder in
            folderSheet(for: folder)
        }
        .task {
            await vm.initialize()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await vm.refreshIfNeeded() }
        }
        .onChange(of: vm.gridItems) { old, new in
            // Save when user manually reorders or deletes — skip on initial load
            guard !new.isEmpty && old != new else { return }
            vm.scheduleSave()
        }
        .onChange(of: vm.folders) { old, new in
            guard old != new else { return }
            vm.scheduleSave()
        }
    }

    // MARK: - Search & Sort Bar

    private var searchSortBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                TextField("Search applications...", text: $vm.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .onChange(of: vm.searchText) { _, _ in
                        vm.currentPageIndex = 0
                        vm.clearSelection()
                    }
            }
            .padding(12)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)

            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        vm.sortOption = option
                        vm.currentPageIndex = 0
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if vm.sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 14))
                    Text("Sort").font(.system(size: 14))
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
    }

    // MARK: - App Grid

    private var appGrid: some View {
        GeometryReader { geometry in
            let cols = vm.calculateColumns(availableWidth: geometry.size.width)
            let rows = vm.calculateRows(availableHeight: geometry.size.height)
            let numPages = vm.calculatePageCount(totalItems: vm.filteredItems.count, rows: rows, cols: cols)
            let safePageIndex = min(vm.currentPageIndex, numPages - 1)

            let itemsPerPage = max(1, rows * cols)

            HStack(spacing: 0) {
                ForEach(0..<numPages, id: \.self) { pageIndex in
                    LazyVGrid(
                        columns: Array(repeating: SwiftUI.GridItem(.fixed(150), spacing: 30), count: cols),
                        spacing: 30
                    ) {
                        ForEach(Array(vm.itemsForPage(pageIndex, rows: rows, cols: cols).enumerated()), id: \.element.id) { localIndex, item in
                            let globalIndex = pageIndex * itemsPerPage + localIndex
                            GridItemButton(
                                item: item,
                                isArrangeMode: $vm.isArrangeMode,
                                draggedItem: $vm.draggedItem,
                                gridItems: $vm.gridItems,
                                folders: $vm.folders,
                                openFolder: $vm.openFolder,
                                filteredItems: vm.filteredItems,
                                isSelected: vm.selectedIndex == globalIndex
                            )
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                }
            }
            .offset(x: -CGFloat(safePageIndex) * geometry.size.width)
            .background(
                Color.clear.onTapGesture {
                    if vm.isArrangeMode { vm.exitArrangeMode() }
                }
            )
            .background(
                ScrollWheelHandler { deltaX in
                    vm.handleScroll(deltaX: deltaX, numPages: numPages, safePageIndex: safePageIndex)
                }
            )
            .preference(key: GridSizeKey.self, value: GridSizeData(rows: rows, columns: cols))
        }
        .onPreferenceChange(GridSizeKey.self) { size in
            // Defer mutations — onPreferenceChange fires during view updates
            // and setting @Published properties here causes "undefined behavior" warnings
            DispatchQueue.main.async {
                vm.gridRows = size.rows
                vm.gridColumns = size.columns
                let numPages = vm.calculatePageCount(
                    totalItems: vm.filteredItems.count,
                    rows: vm.gridRows,
                    cols: vm.gridColumns
                )
                if vm.currentPageIndex >= numPages {
                    vm.currentPageIndex = max(0, numPages - 1)
                }
            }
        }
    }

    // MARK: - Page Indicators

    private var pageIndicators: some View {
        let numPages = vm.calculatePageCount(
            totalItems: vm.filteredItems.count,
            rows: vm.gridRows,
            cols: vm.gridColumns
        )
        return HStack(spacing: 8) {
            ForEach(0..<numPages, id: \.self) { index in
                Circle()
                    .fill(index == vm.currentPageIndex ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            vm.currentPageIndex = index
                        }
                    }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Folder Sheet

    @ViewBuilder
    private func folderSheet(for folder: Folder) -> some View {
        FolderSheetView(
            folder: folder,
            folderName: Binding(
                get: { vm.folders.first { $0.id == folder.id }?.name ?? folder.name },
                set: { newName in
                    guard let idx = vm.folders.firstIndex(where: { $0.id == folder.id }) else { return }
                    vm.folders[idx].name = newName
                    if let itemIdx = vm.gridItems.firstIndex(where: { $0.id == folder.id }) {
                        vm.gridItems[itemIdx] = .folder(vm.folders[idx])
                    }
                    if vm.openFolder?.id == folder.id { vm.openFolder?.name = newName }
                    vm.saveGridOrder()
                }
            ),
            isPresented: Binding(
                get: { vm.openFolder != nil },
                set: { if !$0 { vm.openFolder = nil } }
            ),
            onRemoveApp: { appToRemove in
                withAnimation {
                    guard let folderIdx = vm.folders.firstIndex(where: { $0.id == folder.id }) else { return }
                    vm.folders[folderIdx].apps.removeAll { $0.id == appToRemove.id }

                    if vm.folders[folderIdx].apps.isEmpty {
                        vm.folders.remove(at: folderIdx)
                        vm.gridItems.removeAll {
                            if case .folder(let f) = $0 { return f.id == folder.id }
                            return false
                        }
                        vm.openFolder = nil
                    } else {
                        if let itemIdx = vm.gridItems.firstIndex(where: { $0.id == folder.id }) {
                            vm.gridItems[itemIdx] = .folder(vm.folders[folderIdx])
                        }
                        vm.openFolder = vm.folders[folderIdx]
                    }
                    vm.gridItems.append(.app(appToRemove))
                    vm.saveGridOrder()
                }
            },
            onRenameFolder: { _ in vm.saveGridOrder() },
            onReorderApps: { reorderedApps in
                guard let folderIdx = vm.folders.firstIndex(where: { $0.id == folder.id }) else { return }
                vm.folders[folderIdx].apps = reorderedApps
                if let itemIdx = vm.gridItems.firstIndex(where: { $0.id == folder.id }) {
                    vm.gridItems[itemIdx] = .folder(vm.folders[folderIdx])
                }
                vm.saveGridOrder()
            }
        )
    }
}
