//
//  HistoryRowView.swift
//  CopyPasteMemory
//

import SwiftUI
import AppKit

// Una sola fila de la lista del historial: icono/miniatura + texto + fecha,
// más el botón de pin a la derecha.
struct HistoryRowView: View {
    let item: ClipboardItem
    let isSelected: Bool // si es la fila resaltada por teclado/ratón ahora mismo

    // Closures que nos pasa HistoryPanelView: qué hacer al pulsar la fila
    // (restaurar y cerrar) y qué hacer al pulsar el pin (pinear/despinear).
    // No los llamamos directamente aquí porque HistoryRowView no conoce el
    // store — solo sabe "avisar hacia arriba" de lo que ha pasado.
    let onSelect: () -> Void
    let onTogglePin: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Todo el contenido principal de la fila (icono + texto + fecha)
            // va dentro de un Button propio, para que sea "clicable" sin
            // interferir con el botón del pin de al lado (si usáramos
            // .onTapGesture en todo el HStack, se comería también los
            // toques sobre el botón del pin).
            Button(action: onSelect) {
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
            }
            // .plain quita el aspecto por defecto de botón (fondo, borde...),
            // para que siga pareciendo una fila normal de lista
            .buttonStyle(.plain)

            Button(action: onTogglePin) {
                // pin.fill si está pineado, pin (contorno) si no
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(item.isPinned ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            // Texto que aparece al dejar el ratón un momento encima (tooltip)
            .help(item.isPinned ? "Quitar pin" : "Pinear (sobrevive a un reinicio del Mac)")
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
