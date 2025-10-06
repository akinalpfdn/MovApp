//
//  ContentView.swift
//  MovApp
//
//  Created by Akinalp Fidan on 6.10.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = ApplicationScanner()
    @State private var searchText = ""
    @State private var window: NSWindow?

    // Calculate number of rows that fit in screen
    private var rows: Int {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 900
        let availableHeight = screenHeight - 100 // minus search bar
        let rowHeight: CGFloat = 180 // icon (150) + spacing (30)
        return max(4, Int(availableHeight / rowHeight))
    }

    private var columns: [GridItem] {
        return Array(repeating: GridItem(.fixed(150), spacing: 30), count: rows)
    }

    var filteredApps: [Application] {
        if searchText.isEmpty {
            return scanner.applications
        }
        return scanner.applications.filter { app in
            app.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            // Transparent background
            TransparentWindowView()
                .ignoresSafeArea()

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
                .background(Color.white.opacity(0.1))
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
                    ScrollView(.horizontal) {
                        LazyHGrid(rows: columns, spacing: 30) {
                            ForEach(filteredApps) { app in
                                AppIconView(app: app)
                                    .onTapGesture(count: 2) {
                                        app.launch()
                                    }
                            }
                        }
                        .padding()
                    }
                    .scrollIndicators(.hidden)
                }
            }

            // Window accessor for transparency
            WindowAccessor(window: $window)
        }
        .task {
            await scanner.scanApplications()
        }
    }
}

#Preview {
    ContentView()
}
