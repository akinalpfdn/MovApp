import SwiftUI
import AppKit

struct PagedAppView: NSViewRepresentable {
    let apps: [Application]
    let rows: Int
    let columns: Int

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.usesPredominantAxisScrolling = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = .clear

        // Calculate apps per page
        let appsPerPage = rows * columns
        let pageCount = (apps.count + appsPerPage - 1) / appsPerPage

        let screenWidth = NSScreen.main?.visibleFrame.width ?? 1200
        let totalWidth = screenWidth * CGFloat(pageCount)

        containerView.frame = NSRect(x: 0, y: 0, width: totalWidth, height: 800)

        for pageIndex in 0..<pageCount {
            let pageView = createPageView(pageIndex: pageIndex, appsPerPage: appsPerPage, coordinator: context.coordinator)
            pageView.frame = NSRect(x: screenWidth * CGFloat(pageIndex), y: 0, width: screenWidth, height: 800)
            containerView.addSubview(pageView)
        }

        scrollView.documentView = containerView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {}

    private func createPageView(pageIndex: Int, appsPerPage: Int, coordinator: Coordinator) -> NSView {
        let pageView = NSView()
        pageView.wantsLayer = true
        pageView.layer?.backgroundColor = .clear

        let startIndex = pageIndex * appsPerPage
        let endIndex = min(startIndex + appsPerPage, apps.count)

        guard startIndex < apps.count else { return pageView }

        let pageApps = Array(apps[startIndex..<endIndex])

        // Create grid
        var row = 0
        var col = 0

        for app in pageApps {
            let button = NSButton()
            button.title = ""
            button.image = app.icon
            button.imageScaling = .scaleProportionallyUpOrDown
            button.isBordered = false
            button.target = coordinator
            button.action = #selector(Coordinator.appClicked(_:))
            button.tag = apps.firstIndex(where: { $0.id == app.id }) ?? 0

            let x = CGFloat(col) * 150 + 60
            let y = CGFloat(row) * 180 + 60
            button.frame = NSRect(x: x, y: y, width: 96, height: 96)

            pageView.addSubview(button)

            // Add label
            let label = NSTextField()
            label.stringValue = app.name
            label.isEditable = false
            label.isBordered = false
            label.backgroundColor = .clear
            label.textColor = .white
            label.alignment = .center
            label.font = .systemFont(ofSize: 13)
            label.maximumNumberOfLines = 2
            label.lineBreakMode = .byTruncatingTail
            label.frame = NSRect(x: x - 12, y: y - 40, width: 120, height: 40)

            pageView.addSubview(label)

            col += 1
            if col >= columns {
                col = 0
                row += 1
            }
        }

        return pageView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(apps: apps)
    }

    class Coordinator: NSObject {
        let apps: [Application]

        init(apps: [Application]) {
            self.apps = apps
        }

        @objc func appClicked(_ sender: NSButton) {
            let app = apps[sender.tag]
            app.launch()
        }
    }
}
