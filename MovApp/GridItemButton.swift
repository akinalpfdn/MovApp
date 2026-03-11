import SwiftUI
import UniformTypeIdentifiers

struct GridItemButton: View {
    let item: GridItem
    @Binding var isArrangeMode: Bool
    @Binding var draggedItem: GridItem?
    @Binding var gridItems: [GridItem]
    @Binding var folders: [Folder]
    @Binding var openFolder: Folder?
    let filteredItems: [GridItem]
    let isSelected: Bool

    @State private var wiggleRotation: Double = 0
    @State private var showDeleteConfirmation = false
    @State private var isHoveringOver = false
    @State private var wiggleTimer: Timer?

    var body: some View {
        ZStack(alignment: .topLeading) {
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
                guard !isArrangeMode else { return }
                handleTap()
            }
            .onLongPressGesture(minimumDuration: 0.6) {
                guard !isArrangeMode else { return }
                withAnimation {
                    isArrangeMode = true
                    if gridItems.isEmpty {
                        gridItems = filteredItems
                    }
                }
            }

            if isArrangeMode {
                Button { showDeleteConfirmation = true } label: {
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
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white, lineWidth: 2.5)
                .opacity(isSelected ? 1 : 0)
                .padding(-6)
                .animation(.easeInOut(duration: 0.15), value: isSelected)
        )
        .contextMenu {
            if case .app(let app) = item {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
            }
            Button {
                let name: String
                switch item {
                case .app(let app): name = app.name
                case .folder(let folder): name = folder.name
                }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(name, forType: .string)
            } label: {
                Label("Copy Name", systemImage: "doc.on.clipboard")
            }
            Divider()
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(item.isFolder ? "Delete Folder" : "Move to Trash", systemImage: "trash")
            }
        }
        .alert(alertTitle, isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button(item.isFolder ? "Delete Folder" : "Move to Trash", role: .destructive) {
                handleDelete()
            }
        } message: {
            Text(alertMessage)
        }
        .onDrag {
            guard isArrangeMode else { return NSItemProvider() }
            draggedItem = item
            return NSItemProvider(object: item.id as NSString)
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
                wiggleTimer?.invalidate()
                wiggleTimer = nil
                wiggleRotation = 0
            }
        }
        .onDisappear {
            wiggleTimer?.invalidate()
            wiggleTimer = nil
        }
    }

    // MARK: - Helpers

    private var alertTitle: String {
        switch item {
        case .app(let app): return "Uninstall \(app.name)?"
        case .folder(let folder): return "Delete \(folder.name)?"
        }
    }

    private var alertMessage: String {
        switch item {
        case .app(let app): return "This will move \(app.name) and its related files to the Trash."
        case .folder: return "This will delete the folder. Apps will be moved back to the main grid."
        }
    }

    private func handleTap() {
        switch item {
        case .app(let app): app.launch()
        case .folder(let folder): openFolder = folder
        }
    }

    private func handleDelete() {
        switch item {
        case .app(let app):
            guard app.uninstall() else { return }
            withAnimation {
                gridItems.removeAll { $0.id == item.id }
            }
        case .folder(let folder):
            withAnimation {
                gridItems.removeAll { $0.id == item.id }
                folders.removeAll { $0.id == folder.id }
                gridItems.append(contentsOf: folder.apps.map { .app($0) })
            }
        }
    }

    private func startWiggle() {
        wiggleTimer?.invalidate()
        wiggleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] timer in
            guard isArrangeMode else {
                timer.invalidate()
                return
            }
            withAnimation(.easeInOut(duration: 0.1)) {
                wiggleRotation = Double.random(in: -3...3)
            }
        }
    }
}

// MARK: - Drop Delegate

struct GridItemDropDelegate: DropDelegate {
    let item: GridItem
    @Binding var items: [GridItem]
    @Binding var folders: [Folder]
    @Binding var draggedItem: GridItem?

    func performDrop(info: DropInfo) -> Bool {
        defer { draggedItem = nil }

        guard let dragged = draggedItem else { return true }

        if case .app(let draggedApp) = dragged,
           case .app(let targetApp) = item,
           draggedApp.id != targetApp.id {
            createFolder(draggedApp: draggedApp, targetApp: targetApp)
            return true
        }

        if case .app(let draggedApp) = dragged,
           case .folder(var targetFolder) = item {
            addAppToFolder(app: draggedApp, folder: &targetFolder)
            return true
        }

        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedItem,
              let fromIndex = items.firstIndex(where: { $0.id == dragged.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }),
              fromIndex != toIndex,
              !shouldCreateFolder() else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            items.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    private func shouldCreateFolder() -> Bool {
        guard let dragged = draggedItem else { return false }
        if case .app = dragged, case .app = item { return true }
        return false
    }

    private func createFolder(draggedApp: Application, targetApp: Application) {
        withAnimation {
            guard let targetIndex = items.firstIndex(where: {
                if case .app(let app) = $0 { return app.id == targetApp.id }
                return false
            }) else { return }

            items.removeAll {
                if case .app(let app) = $0 {
                    return app.id == draggedApp.id || app.id == targetApp.id
                }
                return false
            }

            let newFolder = Folder(name: "Folder", apps: [targetApp, draggedApp])
            folders.append(newFolder)
            items.insert(.folder(newFolder), at: min(targetIndex, items.count))
        }
    }

    private func addAppToFolder(app: Application, folder: inout Folder) {
        withAnimation {
            items.removeAll {
                if case .app(let a) = $0 { return a.id == app.id }
                return false
            }
            folder.apps.append(app)
            if let i = folders.firstIndex(where: { $0.id == folder.id }) {
                folders[i] = folder
            }
            if let i = items.firstIndex(where: { $0.id == folder.id }) {
                items[i] = .folder(folder)
            }
        }
    }
}
