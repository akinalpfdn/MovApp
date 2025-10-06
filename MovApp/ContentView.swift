//
//  ContentView.swift
//  MovApp
//
//  Created by Akinalp Fidan on 6.10.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct AppIconButton: View {
    let app: Application
    @Binding var isArrangeMode: Bool
    @Binding var draggedApp: Application?
    @Binding var reorderedApps: [Application]
    let filteredApps: [Application]

    @State private var wiggleRotation: Double = 0

    var body: some View {
        Button(action: {
            if !isArrangeMode {
                print("CLICKED: \(app.name)")
                app.launch()
            }
        }) {
            AppIconView(app: app)
                .opacity(draggedApp?.id == app.id && isArrangeMode ? 0.5 : 1.0)
                .rotationEffect(.degrees(wiggleRotation))
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 1.0, perform: {
            // Action on completion
        }, onPressingChanged: { isPressing in
            if isPressing {
                withAnimation {
                    isArrangeMode = true
                    if reorderedApps.isEmpty {
                        reorderedApps = filteredApps
                    }
                }
            }
        })
        .onDrag {
            if isArrangeMode {
                draggedApp = app
                return NSItemProvider(object: app.id as NSString)
            }
            return NSItemProvider()
        }
        .onDrop(of: [.text], delegate: AppDropDelegate(
            app: app,
            apps: $reorderedApps,
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

struct AppDropDelegate: DropDelegate {
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

struct ContentView: View {
    @StateObject private var scanner = ApplicationScanner()
    @State private var searchText = ""
    @State private var window: NSWindow?
    @State private var currentPageIndex = 0
    @State private var lastScrollTime: Date = Date()
    @State private var isArrangeMode = false
    @State private var draggedApp: Application?
    @State private var reorderedApps: [Application] = []
    
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
    
    var filteredApps: [Application] {
        let apps = reorderedApps.isEmpty ? scanner.applications : reorderedApps

        if searchText.isEmpty {
            return apps
        }
        return apps.filter { app in
            app.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Split apps into pages
    func appsForPage(_ pageIndex: Int) -> [Application] {
        let appsPerPage = rows * columns
        let startIndex = pageIndex * appsPerPage
        let endIndex = min(startIndex + appsPerPage, filteredApps.count)
        
        guard startIndex < filteredApps.count else { return [] }
        return Array(filteredApps[startIndex..<endIndex])
    }
    
    func numberOfPages() -> Int {
        let appsPerPage = rows * columns
        return max(1, (filteredApps.count + appsPerPage - 1) / appsPerPage)
    }
    
    var body: some View {
   
            VStack(spacing: 0) {
                // Search bar
                HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("Search applications...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            .padding()
            
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
                                    columns: Array(repeating: GridItem(.fixed(150), spacing: 30), count: columns),
                                    spacing: 30
                                ) {
                                    ForEach(appsForPage(pageIndex)) { app in
                                        AppIconButton(
                                            app: app,
                                            isArrangeMode: $isArrangeMode,
                                            draggedApp: $draggedApp,
                                            reorderedApps: $reorderedApps,
                                            filteredApps: filteredApps
                                        )
                                    }
                                }
                                .frame(width: pageWidth)
                                .id(pageIndex)
                            }
                        }
                        .offset(x: totalOffset)
                        .background(
                            ScrollWheelHandler { deltaX in
                                let now = Date()
                                let timeSinceLastScroll = now.timeIntervalSince(lastScrollTime)

                                // Debounce: only process if 0.15 seconds have passed
                                guard timeSinceLastScroll > 0.15 else { return }

                                let threshold: CGFloat = 5

                                if abs(deltaX) >= threshold {
                                    lastScrollTime = now

                                    if deltaX < 0 && currentPageIndex < numberOfPages() - 1 {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.92)) {
                                            currentPageIndex += 1
                                        }
                                    } else if deltaX > 0 && currentPageIndex > 0 {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.92)) {
                                            currentPageIndex -= 1
                                        }
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
                        draggedApp = nil
                    }
                    return .handled
                }
                return .ignored
            }

        .task {
            await scanner.scanApplications()
        }
    }
    
    
}
