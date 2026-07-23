//
//  HistoryPanelController.swift
//  CopyPasteMemory
//

import AppKit
import SwiftUI

/// Owns a single reusable floating NSPanel that shows the clipboard history.
/// A plain SwiftUI Window/MenuBarExtra popover can't reliably appear above
/// every app regardless of focus (e.g. while another app owns a fullscreen
/// Space), so this uses a purpose-built panel instead.
final class HistoryPanelController: NSObject, NSWindowDelegate {
    private let store: ClipboardHistoryStore
    private var panel: NSPanel?
    private var resignObserver: NSObjectProtocol?

    init(store: ClipboardHistoryStore) {
        self.store = store
    }

    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let panel = panelInstance()
        positionNearCursor(panel)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func panelInstance() -> NSPanel {
        if let panel { return panel }

        let hostingView = NSHostingView(
            rootView: HistoryPanelView(store: store, onDismiss: { [weak self] in
                self?.hide()
            })
        )

        let newPanel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isMovableByWindowBackground = true
        newPanel.hidesOnDeactivate = false
        newPanel.contentView = hostingView
        newPanel.delegate = self

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: newPanel,
            queue: .main
        ) { [weak self] _ in
            self?.hide()
        }

        panel = newPanel
        return newPanel
    }

    private func positionNearCursor(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }

        var origin = NSPoint(
            x: mouseLocation.x - panel.frame.width / 2,
            y: mouseLocation.y - panel.frame.height - 12
        )

        let screenFrame = screen.visibleFrame
        origin.x = min(max(origin.x, screenFrame.minX), screenFrame.maxX - panel.frame.width)
        origin.y = min(max(origin.y, screenFrame.minY), screenFrame.maxY - panel.frame.height)

        panel.setFrameOrigin(origin)
    }
}

/// A .nonactivatingPanel normally can't become key, which would block keyboard
/// navigation (arrows/Enter/Escape). Overriding this lets it accept keyboard
/// input without stealing frontmost-application status from the app the user
/// was just in.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
