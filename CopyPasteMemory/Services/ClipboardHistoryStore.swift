//
//  ClipboardHistoryStore.swift
//  CopyPasteMemory
//

import AppKit
import Combine

// Los motivos por los que un pin puede rechazarse. LocalizedError nos deja
// definir un mensaje legible en errorDescription, que la UI puede mostrar
// directamente en una alerta sin tener que traducir el error a mano.
enum PinError: LocalizedError, Identifiable {
    case tooLarge

    var id: String { "tooLarge" } // para poder usarlo con .alert(item:) en SwiftUI

    var errorDescription: String? {
        "Este elemento es demasiado grande para guardarlo de forma permanente (máx. 100 KB de texto o 5 MB de imagen)."
    }
}

// ObservableObject es un protocolo de Combine/SwiftUI: cuando una propiedad
// marcada con @Published cambia, cualquier vista de SwiftUI que la esté
// leyendo (con @ObservedObject) se redibuja sola automáticamente.
//
// El historial normal vive SOLO en memoria (se pierde al cerrar la app, a
// propósito). Los items "pineados" son la excepción: se persisten aparte
// mediante PinnedItemStore, y por eso nunca los borra el límite de 25 ni
// "Vaciar historial".
final class ClipboardHistoryStore: ObservableObject {
    // private(set): cualquiera puede LEER `items`, pero solo esta clase puede
    // modificarlo (evita que una vista intente añadir/quitar items directamente).
    @Published private(set) var items: [ClipboardItem] = []

    // Cuando un intento de pin falla (por tamaño), lo dejamos aquí para que
    // la vista lo detecte y muestre una alerta. Volver a ponerlo a nil es
    // cosa de la propia vista, al cerrar la alerta.
    @Published var pinError: PinError?

    private let maxItems = 25
    private let pasteboard = NSPasteboard.general
    private let pinnedStore = PinnedItemStore()

    // Límites de tamaño para poder pinear algo. Son generosos para un uso
    // normal (cualquier fragmento de texto o captura de pantalla típica
    // entra de sobra) pero evitan forzar el Llavero con textos gigantes o
    // llenar el disco con imágenes enormes.
    private static let maxPinnedTextBytes = 100_000     // ~100 KB
    private static let maxPinnedImageBytes = 5_000_000  // ~5 MB

    // Avisa a quien esté escuchando (AppDelegate) justo después de escribir
    // en el portapapeles, para que ClipboardMonitor no vuelva a capturar
    // esta escritura como si fuera una copia nueva del usuario.
    var onWroteToPasteboard: (() -> Void)?

    // Al crear el store, recuperamos los pines guardados de sesiones
    // anteriores, para que ya aparezcan en el historial desde el arranque.
    init() {
        items = pinnedStore.loadAll()
    }

    // La llama ClipboardMonitor cada vez que detecta algo nuevo copiado.
    func add(_ content: ClipboardContent) {
        let hash = content.hashDigest

        if let existingIndex = items.firstIndex(where: { $0.contentHash == hash }) {
            // Si el duplicado es un pin, lo dejamos tal cual donde está —
            // no tiene sentido "reordenarlo" ni tocarlo.
            if items[existingIndex].isPinned {
                return
            }
            items.remove(at: existingIndex)
        }

        // Los items nuevos siempre entran en primera posición (el más reciente arriba)
        items.insert(ClipboardItem(content: content), at: 0)

        // El límite de 25 aplica SOLO a los elementos sin pinear — los
        // pineados no cuentan y nunca se recortan por antigüedad.
        let unpinnedIndices = items.indices.filter { !items[$0].isPinned }
        if unpinnedIndices.count > maxItems {
            let overflow = unpinnedIndices.count - maxItems
            // .suffix(overflow) = los más antiguos sin pinear (los últimos
            // de la lista, ya que los nuevos siempre entran al principio).
            // Los borramos de índice mayor a menor para no desordenar los
            // índices restantes mientras vamos eliminando.
            for index in unpinnedIndices.suffix(overflow).sorted(by: >) {
                items.remove(at: index)
            }
        }
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
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let restored = items.remove(at: index)
        items.insert(restored, at: 0)
    }

    // Se llama al pulsar el icono del pin en una fila. Si ya estaba pineado,
    // lo despinea (y lo borra de disco/Keychain); si no, intenta pinearlo
    // (comprobando antes que no sea demasiado grande).
    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        if items[index].isPinned {
            items[index].isPinned = false
            pinnedStore.remove(id: items[index].id)
            return
        }

        guard Self.fitsWithinPinLimits(items[index].content) else {
            pinError = .tooLarge
            return
        }

        items[index].isPinned = true
        pinnedStore.save(items[index])
    }

    private static func fitsWithinPinLimits(_ content: ClipboardContent) -> Bool {
        switch content {
        case .text(let string):
            return string.utf8.count <= maxPinnedTextBytes
        case .image(let data):
            return data.count <= maxPinnedImageBytes
        }
    }

    // La usa el botón "Vaciar historial" del menú de la barra de estado.
    // Los pines NO se tocan aquí: el usuario los guardó a propósito, así
    // que solo "vaciar" debe afectar al historial normal.
    func clearHistory() {
        items.removeAll { !$0.isPinned }
    }
}
