//
//  HistoryRowView.swift
//  CopyPasteMemory
//

import SwiftUI
import AppKit

// Una sola fila de la lista del historial: icono/miniatura + texto + fecha.
struct HistoryRowView: View {
    let item: ClipboardItem
    let isSelected: Bool // si es la fila resaltada por teclado/ratón ahora mismo

    var body: some View {
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                preview
                // style: .relative muestra "hace 2 minutos" en vez de la fecha exacta
                Text(item.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0) // empuja todo hacia la izquierda
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            // Fondo resaltado solo si esta fila está seleccionada
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
    }

    // @ViewBuilder permite que esta propiedad devuelva vistas distintas
    // según el `case` del enum, como si fuera un pequeño "if/switch" de vistas.
    @ViewBuilder
    private var icon: some View {
        switch item.content {
        case .text:
            Image(systemName: "text.alignleft")
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
        case .image(let data):
            // Reconstruimos un NSImage a partir de los bytes PNG guardados
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill) // recorta manteniendo proporción, como una miniatura
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                // Por si los datos estuvieran corruptos (no debería pasar)
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
                .lineLimit(1) // una sola línea, aunque el texto sea largo
                .truncationMode(.tail) // "...", corta por el final
        case .image:
            Text("Imagen")
                .font(.body)
        }
    }
}
