//
//  AppDelegate.swift
//  CopyPasteMemory
//

import Cocoa

/// Owns the pieces SwiftUI's App/Scene lifecycle has no clean hook for:
/// registering the global hotkey once, keeping a single reusable NSPanel,
/// and running cleanup on quit.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let historyStore = ClipboardHistoryStore()

    private let monitor = ClipboardMonitor()
    private let hotKeyManager = HotKeyManager()
    private var panelController: HistoryPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        panelController = HistoryPanelController(store: historyStore)

        monitor.onNewContent = { [weak self] content in
            self?.historyStore.add(content)
        }
        historyStore.onWroteToPasteboard = { [weak self] in
            self?.monitor.acknowledgeExternalWrite()
        }
        hotKeyManager.onHotKeyPressed = { [weak self] in
            self?.panelController?.toggle()
        }

        hotKeyManager.register()
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
        monitor.stop()
    }

    func showHistoryPanel() {
        panelController?.show()
    }
}
