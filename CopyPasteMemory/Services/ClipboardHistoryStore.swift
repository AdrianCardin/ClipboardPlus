//
//  ClipboardHistoryStore.swift
//  CopyPasteMemory
//

import AppKit
import Combine

// ObservableObject es un protocolo de Combine/SwiftUI: cuando una propiedad
// marcada con @Published cambia, cualquier vista de SwiftUI que la esté
// leyendo (con @ObservedObject) se redibuja sola automáticamente.
// Aquí guardamos el historial de copias en memoria (no en disco).
final class ClipboardHistoryStore: ObservableObject {
    // private(set): cualquiera puede LEER `items`, pero solo esta clase puede
    // modificarlo (evita que una vista intente añadir/quitar items directamente).
    @Published private(set) var items: [ClipboardItem] = []

    private let maxItems = 25
    private let pasteboard = NSPasteboard.general

    // Avisa a quien esté escuchando (AppDelegate) justo después de escribir
    // en el portapapeles, para que ClipboardMonitor no vuelva a capturar
    // esta escritura como si fuera una copia nueva del usuario.
    var onWroteToPasteboard: (() -> Void)?

    // La llama ClipboardMonitor cada vez que detecta algo nuevo copiado.
    func add(_ content: ClipboardContent) {
        let hash = content.hashDigest

        var newItems = items
        // Si ya existía un item con el mismo contenido, lo quitamos de su
        // posición actual (para no tener duplicados)...
        newItems.removeAll { $0.contentHash == hash }
        // ...y lo volvemos a insertar al principio (el más reciente siempre arriba)
        newItems.insert(ClipboardItem(content: content), at: 0)

        // Si nos pasamos de 25, recortamos los más antiguos (el final del array)
        if newItems.count > maxItems {
            newItems.removeLast(newItems.count - maxItems)
        }

        // Asignar a `items` (que es @Published) dispara la actualización de la UI
        items = newItems
    }

    // Se llama cuando el usuario elige un item del panel de historial.
    // Escribe ese contenido en el portapapeles del sistema, para que luego
    // el usuario pueda pegarlo con un Cmd+V normal.
    func selectAndRestore(_ item: ClipboardItem) {
        pasteboard.clearContents() // vacía el portapapeles antes de escribir
        switch item.content {
        case .text(let string):
            pasteboard.setString(string, forType: .string)
        case .image(let data):
            pasteboard.setData(data, forType: .png)
        }

        // Avisamos al monitor para que no se confunda con este cambio
        onWroteToPasteboard?()

        // Además, movemos este item a la primera posición del historial
        // (como si acabara de copiarse), sin duplicarlo
        var newItems = items
        newItems.removeAll { $0.id == item.id }
        newItems.insert(item, at: 0)
        items = newItems
    }

    // La usa el botón "Vaciar historial" del menú de la barra de estado
    func clearHistory() {
        items = []
    }
}
