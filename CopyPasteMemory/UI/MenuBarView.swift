//
//  MenuBarView.swift
//  CopyPasteMemory
//

import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var store: ClipboardHistoryStore

    var body: some View {
        Button("Mostrar historial (⌘⌥V)") {
            (NSApp.delegate as? AppDelegate)?.showHistoryPanel()
        }

        Divider()

        Button("Vaciar historial") {
            store.clearHistory()
        }
        .disabled(store.items.isEmpty)

        Divider()

        Button("Salir de CopyPasteMemory") {
            NSApp.terminate(nil)
        }
    }
}
