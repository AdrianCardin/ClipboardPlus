//
//  MenuBarView.swift
//  CopyPasteMemory
//

import SwiftUI
import AppKit

// Contenido del menú desplegable que aparece al hacer clic en el icono de
// la barra de menú (ver MenuBarExtra en CopyPasteMemoryApp.swift). Cada
// Button de aquí se convierte automáticamente en una fila del menú.
struct MenuBarView: View {
    // @ObservedObject: aunque este menú no muestra la lista de items en sí,
    // sí necesita saber si hay items o no (para activar/desactivar "Vaciar")
    @ObservedObject var store: ClipboardHistoryStore

    // En vez de buscar el AppDelegate nosotros mismos (con NSApp.delegate as?
    // AppDelegate, que fallaba en silencio al pulsar desde este menú), quien
    // crea esta vista (CopyPasteMemoryApp) nos pasa directamente la función a
    // llamar. Así no dependemos de "encontrar" nada en tiempo de ejecución.
    let onShowHistory: () -> Void

    var body: some View {
        Button("Mostrar historial (⌘⌥V)") {
            onShowHistory()
        }

        Divider() // línea separadora entre grupos de opciones

        Button("Vaciar historial") {
            // clearHistory() respeta los pines, solo borra lo no pineado
            store.clearHistory()
        }
        // Deshabilitado si no queda nada SIN pinear que vaciar
        // (si todo lo que hay son pines, este botón no tendría nada que hacer)
        .disabled(store.items.allSatisfy { $0.isPinned })

        Divider()

        Button("Salir de CopyPasteMemory") {
            NSApp.terminate(nil) // cierra la app por completo
        }
    }
}
