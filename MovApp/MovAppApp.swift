import SwiftUI
import ServiceManagement
import Carbon.HIToolbox

@main
struct MovAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    nonisolated(unsafe) static weak var instance: AppDelegate?

    private var hotKeyRef: EventHotKeyRef?
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self

        if SMAppService.mainApp.status == .notRegistered {
            try? SMAppService.mainApp.register()
        }

        // Store strong reference so we always find the right window
        mainWindow = NSApplication.shared.windows.first

        if let window = mainWindow {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isOpaque = false
            window.backgroundColor = .clear

            if let screen = NSScreen.main {
                window.setFrame(screen.visibleFrame, display: true)
            }
            window.center()
        }

        registerGlobalHotKey()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // Return false → we handle reopen ourselves; SwiftUI won't create a second window
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return false
    }

    // MARK: - Window management

    func showWindow() {
        guard let window = mainWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func toggleWindow() {
        guard let window = mainWindow else { return }
        if window.isVisible && window.isKeyWindow {
            window.orderOut(nil)
        } else {
            showWindow()
        }
    }

    static func hideMainWindow() {
        AppDelegate.instance?.mainWindow?.orderOut(nil)
    }

    // MARK: - Global Hot Key (Option + Space)

    private func registerGlobalHotKey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = 0x4D564150 // "MVAP"
        hotKeyID.id = 1

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ -> OSStatus in
                Task { @MainActor in AppDelegate.instance?.toggleWindow() }
                return noErr
            },
            1, &eventSpec, nil, nil
        )

        RegisterEventHotKey(49, UInt32(optionKey), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
