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
    @State private var currentPageIndex = 0
    
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
                TabView(selection: $currentPageIndex) {
                    ForEach(0..<numberOfPages(), id: \.self) { pageIndex in
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 30), count: columns), spacing: 30) {
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
                        .padding(30)
                        .tag(pageIndex)
                    }
                }
                .tabViewStyle(.automatic)
            }
            }.background(.ultraThinMaterial)
         
        .task {
            await scanner.scanApplications()
        }
    }
    
    
}
