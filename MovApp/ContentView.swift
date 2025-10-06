//
//  ContentView.swift
//  MovApp
//
//  Created by Akinalp Fidan on 6.10.2025.
//

import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
        if searchText.isEmpty {
            return scanner.applications
        }
        return scanner.applications.filter { app in
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
                                        Button(action: {
                                            print("CLICKED: \(app.name)")
                                            app.launch()
                                        }) {
                                            AppIconView(app: app)
                                        }
                                        .buttonStyle(.plain)
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
         
        .task {
            await scanner.scanApplications()
        }
    }
    
    
}
