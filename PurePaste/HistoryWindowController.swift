import SwiftUI
import AppKit

// MARK: - 历史窗口控制器

@MainActor
final class HistoryWindowController {
    static let shared = HistoryWindowController()

    private var window: NSWindow?

    var isShowing: Bool { window?.isVisible == true }

    private init() {}

    // MARK: - 显示/关闭

    func toggle() {
        if isShowing {
            close()
        } else {
            show()
        }
    }

    func show() {
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: HistoryView())

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = L10n.historyTitle
        win.titlebarAppearsTransparent = true
        win.isReleasedWhenClosed = false
        win.contentView = hostingView
        win.center()
        win.setFrameAutosaveName("PurePasteHistory")
        win.isMovableByWindowBackground = true
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = win
    }

    func close() {
        window?.close()
        window = nil
    }
}
