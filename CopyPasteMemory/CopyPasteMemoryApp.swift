//
//  CopyPasteMemoryApp.swift
//  CopyPasteMemory
//
//  Created by Adrián Cardín Lozano on 23/07/2026.
//

import SwiftUI

// @main marca el punto de entrada de la app: es lo primero que se ejecuta.
@main
struct CopyPasteMemoryApp: App {
    // Este "property wrapper" conecta nuestro AppDelegate (clase de AppKit,
    // ver AppDelegate.swift) con el mundo de SwiftUI. Sin esto, SwiftUI no
    // sabría que existe y nunca llamaría a applicationDidFinishLaunching.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // `body` describe la interfaz de la app. En vez de una ventana normal
    // (WindowGroup), usamos MenuBarExtra: un icono en la barra de menú de
    // arriba a la derecha, con un desplegable al hacer clic. No hay ninguna
    // ventana grande — toda la app "vive" en la barra de menú y en el panel
    // flotante que abre HistoryPanelController.
    var body: some Scene {
        MenuBarExtra("CopyPasteMemory", systemImage: "doc.on.clipboard") {
            // Le pasamos el historial (creado dentro de appDelegate) para que
            // el menú pueda mostrar cuántos items hay y vaciarlo si se pide,
            // y la propia función showHistoryPanel (sin paréntesis: así se
            // pasa como una referencia a la función, no se llama todavía).
            MenuBarView(store: appDelegate.historyStore, onShowHistory: appDelegate.showHistoryPanel)
        }
    }
}
