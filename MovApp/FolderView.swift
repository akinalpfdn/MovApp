import SwiftUI
import UniformTypeIdentifiers

struct FolderAppButton: View {
    let app: Application
    @Binding var isArrangeMode: Bool
    @Binding var draggedApp: Application?
    @Binding var folderApps: [Application]
    let onTap: () -> Void
    let onRemove: () -> Void

    @State private var wiggleRotation: Double = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            AppIconView(app: app)
                .opacity(draggedApp?.id == app.id && isArrangeMode ? 0.5 : 1.0)
                .rotationEffect(.degrees(wiggleRotation))
                .onTapGesture {
                    if !isArrangeMode {
                        onTap()
                    }
                }
                .onLongPressGesture(minimumDuration: 0.6) {
                    if !isArrangeMode {
                        withAnimation {
                            isArrangeMode = true
                        }
                    }
                }

            // Remove button in arrange mode
            if isArrangeMode {
                Button(action: onRemove) {
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
        .onDrag {
            if isArrangeMode {
                draggedApp = app
                return NSItemProvider(object: app.id as NSString)
            }
            return NSItemProvider()
        }
        .onDrop(of: [.text], delegate: FolderAppDropDelegate(
            app: app,
            apps: $folderApps,
            draggedApp: $draggedApp
        ))
        .onChange(of: isArrangeMode) { _, newValue in
            if newValue {
                startWiggle()
            } else {
                wiggleRotation = 0
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

struct FolderAppDropDelegate: DropDelegate {
    let app: Application
    @Binding var apps: [Application]
    @Binding var draggedApp: Application?

    func performDrop(info: DropInfo) -> Bool {
        draggedApp = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedApp = draggedApp,
              let fromIndex = apps.firstIndex(where: { $0.id == draggedApp.id }),
              let toIndex = apps.firstIndex(where: { $0.id == app.id }),
              fromIndex != toIndex else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            apps.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
}

struct FolderIconView: View {
    let folder: Folder

    var body: some View {
        ZStack {
            // Folder background
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.15))
                .frame(width: 150, height: 150)

            // App previews (show first 4 apps)
            let previewApps = Array(folder.apps.prefix(4))

            if !previewApps.isEmpty {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach(0..<min(2, previewApps.count), id: \.self) { i in
                            Image(nsImage: previewApps[i].icon)
                                .resizable()
                                .frame(width: 40, height: 40)
                        }
                    }

                    if previewApps.count > 2 {
                        HStack(spacing: 4) {
                            ForEach(2..<min(4, previewApps.count), id: \.self) { i in
                                Image(nsImage: previewApps[i].icon)
                                    .resizable()
                                    .frame(width: 40, height: 40)
                            }
                        }
                    }
                }
            }

            // Folder name
            VStack {
                Spacer()
                Text(folder.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        .frame(width: 150, height: 150)
    }
}

struct FolderSheetView: View {
    let folder: Folder
    @Binding var isPresented: Bool
    let onRemoveApp: (Application) -> Void
    let onRenameFolder: (String) -> Void
    let onReorderApps: ([Application]) -> Void

    @State private var editingName = false
    @State private var folderName: String
    @State private var isArrangeMode = false
    @State private var draggedApp: Application?
    @State private var folderApps: [Application]

    init(folder: Folder, isPresented: Binding<Bool>, onRemoveApp: @escaping (Application) -> Void, onRenameFolder: @escaping (String) -> Void, onReorderApps: @escaping ([Application]) -> Void) {
        self.folder = folder
        self._isPresented = isPresented
        self.onRemoveApp = onRemoveApp
        self.onRenameFolder = onRenameFolder
        self.onReorderApps = onReorderApps
        self._folderName = State(initialValue: folder.name)
        self._folderApps = State(initialValue: folder.apps)
    }

    var body: some View {
        ZStack {
            // Background drop zone - if app is dragged here, remove from folder
            if isArrangeMode && draggedApp != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .onDrop(of: [.text], isTargeted: nil) { providers in
                        if let app = draggedApp {
                            onRemoveApp(app)
                            draggedApp = nil
                            return true
                        }
                        return false
                    }
            }

            VStack(spacing: 20) {
                // Header
                HStack {
                    Spacer()

                    if editingName {
                        TextField("Folder Name", text: $folderName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .onSubmit {
                                if !folderName.isEmpty {
                                    onRenameFolder(folderName)
                                }
                                editingName = false
                            }
                    } else {
                        Text(folder.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .onTapGesture {
                                folderName = folder.name
                                editingName = true
                            }
                    }

                    Spacer()

                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding()

            // Apps grid
            ScrollView {
                LazyVGrid(columns: Array(repeating: SwiftUI.GridItem(.fixed(150), spacing: 30), count: 4), spacing: 30) {
                    ForEach(folderApps) { app in
                        FolderAppButton(
                            app: app,
                            isArrangeMode: $isArrangeMode,
                            draggedApp: $draggedApp,
                            folderApps: $folderApps,
                            onTap: {
                                app.launch()
                                isPresented = false
                            },
                            onRemove: {
                                onRemoveApp(app)
                            }
                        )
                    }
                }
                .padding()
            }
            }
            .frame(width: 700, height: 500)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
        .onKeyPress(.escape) {
            if isArrangeMode {
                withAnimation {
                    isArrangeMode = false
                    draggedApp = nil
                }
                // Save reordered apps
                onReorderApps(folderApps)
                return .handled
            }
            return .ignored
        }
        .onChange(of: folder.apps) { _, newApps in
            folderApps = newApps
        }
    }
}
