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
            // DispatchQueue.main.async: en vez de mostrar el panel AHORA
            // MISMO (mientras el menú de la barra de estado todavía se está
            // cerrando), lo aplazamos a "la próxima vez que el sistema esté
            // libre" — un instante después, pero suficiente para que el
            // cierre del menú termine antes de que aparezca el panel.
            //
            // Sin esto, el panel se abre y macOS le devuelve el foco a la
            // app anterior casi a la vez (por el cierre del menú), y como el
            // panel se auto-oculta al perder el foco (ver
            // didResignKeyNotification en HistoryPanelController), se abre
            // y se cierra solo, tan rápido que parece que "no ha hecho nada".
            DispatchQueue.main.async {
                // NSApp.delegate es "el AppDelegate de la app en marcha". Lo
                // convertimos (as?) a nuestro tipo concreto para poder llamar
                // a showHistoryPanel(), que es un método nuestro, no de AppKit.
                (NSApp.delegate as? AppDelegate)?.showHistoryPanel()
            }
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
