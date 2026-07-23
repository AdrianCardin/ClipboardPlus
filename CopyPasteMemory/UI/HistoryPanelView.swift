//
//  HistoryPanelView.swift
//  CopyPasteMemory
//

import SwiftUI

struct HistoryPanelView: View {
    @ObservedObject var store: ClipboardHistoryStore
    var onDismiss: () -> Void

    @State private var selectedID: ClipboardItem.ID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(width: 360, height: 420)
        .background(.regularMaterial)
        .onAppear { selectedID = store.items.first?.id }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onKeyPress(.return) {
            selectCurrent()
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
    }

    private var header: some View {
        HStack {
            Text("Historial de portapapeles")
                .font(.headline)
            Spacer()
            Text("\(store.items.count)/25")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Copia algo para empezar")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(store.items) { item in
                        HistoryRowView(item: item, isSelected: item.id == selectedID)
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                select(item)
                            }
                    }
                }
                .padding(6)
            }
            .onChange(of: selectedID) { _, newValue in
                guard let newValue else { return }
                proxy.scrollTo(newValue, anchor: .center)
            }
        }
    }

    private func moveSelection(by offset: Int) {
        guard !store.items.isEmpty else { return }
        let currentIndex = store.items.firstIndex(where: { $0.id == selectedID }) ?? 0
        let newIndex = min(max(currentIndex + offset, 0), store.items.count - 1)
        selectedID = store.items[newIndex].id
    }

    private func selectCurrent() {
        guard let selectedID, let item = store.items.first(where: { $0.id == selectedID }) else { return }
        select(item)
    }

    private func select(_ item: ClipboardItem) {
        store.selectAndRestore(item)
        onDismiss()
    }
}
