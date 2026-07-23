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

    var body: some View {
        Button("Mostrar historial (⌘⌥V)") {
            // NSApp.delegate es "el AppDelegate de la app en marcha". Lo
            // convertimos (as?) a nuestro tipo concreto para poder llamar
            // a showHistoryPanel(), que es un método nuestro, no de AppKit.
            (NSApp.delegate as? AppDelegate)?.showHistoryPanel()
        }

        Divider() // línea separadora entre grupos de opciones

        Button("Vaciar historial") {
            store.clearHistory()
        }
        // Deshabilitado (en gris) si no hay nada que vaciar
        .disabled(store.items.isEmpty)

        Divider()

        Button("Salir de CopyPasteMemory") {
            NSApp.terminate(nil) // cierra la app por completo
        }
    }
}
