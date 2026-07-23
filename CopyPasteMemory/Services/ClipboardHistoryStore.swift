//
//  ClipboardHistoryStore.swift
//  CopyPasteMemory
//

import AppKit
import Combine

/// In-memory rolling history of the last `maxItems` copied clipboard entries.
final class ClipboardHistoryStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let maxItems = 25
    private let pasteboard = NSPasteboard.general

    /// Fired after this store writes content back to the pasteboard, so callers
    /// (the ClipboardMonitor) can avoid re-capturing our own write as new content.
    var onWroteToPasteboard: (() -> Void)?

    func add(_ content: ClipboardContent) {
        let hash = content.hashDigest
        var newItems = items
        newItems.removeAll { $0.contentHash == hash }
        newItems.insert(ClipboardItem(content: content), at: 0)
        if newItems.count > maxItems {
            newItems.removeLast(newItems.count - maxItems)
        }
        items = newItems
    }

    /// Writes the item back to the system pasteboard and moves it to the front
    /// of the history (most-recently-used), ready for the user to paste with Cmd+V.
    func selectAndRestore(_ item: ClipboardItem) {
        pasteboard.clearContents()
        switch item.content {
        case .text(let string):
            pasteboard.setString(string, forType: .string)
        case .image(let data):
            pasteboard.setData(data, forType: .png)
        }
        onWroteToPasteboard?()

        var newItems = items
        newItems.removeAll { $0.id == item.id }
        newItems.insert(item, at: 0)
        items = newItems
    }

    func clearHistory() {
        items = []
    }
}
