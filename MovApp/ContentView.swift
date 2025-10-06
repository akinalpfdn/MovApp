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

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 30), count: 8)

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
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 30) {
                            ForEach(filteredApps) { app in
                                AppIconView(app: app)
                                    .onTapGesture(count: 2) {
                                        app.launch()
                                    }
                            }
                        }
                        .padding()
                    }
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
