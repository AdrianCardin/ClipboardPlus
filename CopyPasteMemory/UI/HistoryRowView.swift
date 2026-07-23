//
//  HistoryRowView.swift
//  CopyPasteMemory
//

import SwiftUI
import AppKit

struct HistoryRowView: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                preview
                Text(item.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
    }

    @ViewBuilder
    private var icon: some View {
        switch item.content {
        case .text:
            Image(systemName: "text.alignleft")
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
        case .image(let data):
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch item.content {
        case .text(let string):
            Text(string)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
        case .image:
            Text("Imagen")
                .font(.body)
        }
    }
}
