import SwiftUI

/// Monitors horizontal scroll wheel events at the application level.
/// Using a local event monitor is more reliable than overriding scrollWheel(with:)
/// on an NSView, which depends on uncertain first-responder/hit-testing behaviour.
struct ScrollWheelHandler: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onScroll = onScroll
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScroll: onScroll) }

    final class Coordinator {
        var onScroll: (CGFloat) -> Void
        private var monitor: Any?

        init(onScroll: @escaping (CGFloat) -> Void) {
            self.onScroll = onScroll
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.onScroll(event.scrollingDeltaX)
                return event  // don't consume — let other views receive it too
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
