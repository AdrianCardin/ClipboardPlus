//
//  AppDelegate.swift
//  CopyPasteMemory
//

import Cocoa

// SwiftUI (App/Scene) no tiene un buen sitio para hacer "arranque imperativo":
// cosas que solo deben pasar UNA vez al lanzar la app, como registrar un
// atajo global o crear una única ventana flotante reutilizable. Para eso
// seguimos usando el patrón clásico de AppKit: un AppDelegate.
final class AppDelegate: NSObject, NSApplicationDelegate {
    // `let` (no @Published aquí; el @Published importante ya está dentro
    // del propio store). Se crea en cuanto se crea el AppDelegate, es decir,
    // antes incluso de que termine de lanzarse la app — así CopyPasteMemoryApp
    // ya puede pasárselo a MenuBarView sin esperar a nada.
    let historyStore = ClipboardHistoryStore()

    private let monitor = ClipboardMonitor()
    private let hotKeyManager = HotKeyManager()
    private var panelController: HistoryPanelController?

    // Este método lo llama el sistema automáticamente cuando la app ya ha
    // terminado de arrancar. Aquí "conectamos los cables" entre las piezas.
    func applicationDidFinishLaunching(_ notification: Notification) {
        // .accessory = "app de utilidad": sin icono en el Dock, solo en la
        // barra de menú. (Esto se combina con LSUIElement=YES en Info.plist,
        // que hace lo mismo mucho antes, antes de que este código se ejecute).
        NSApp.setActivationPolicy(.accessory)

        panelController = HistoryPanelController(store: historyStore)

        // Cuando el monitor detecta algo nuevo copiado, lo guardamos en el store
        monitor.onNewContent = { [weak self] content in
            self?.historyStore.add(content)
        }

        // Cuando el store escribe algo en el portapapeles (al restaurar un item),
        // avisamos al monitor para que no lo vuelva a capturar como "nuevo"
        historyStore.onWroteToPasteboard = { [weak self] in
            self?.monitor.acknowledgeExternalWrite()
        }

        // Cuando se pulsa Cmd+Option+V, mostramos/ocultamos el panel
        hotKeyManager.onHotKeyPressed = { [weak self] in
            self?.panelController?.toggle()
        }

        hotKeyManager.register() // empieza a escuchar el atajo
        monitor.start()          // empieza a comprobar el portapapeles cada 0.4s
    }

    // Se llama justo antes de cerrar la app: liberamos recursos para dejarlo todo limpio
    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
        monitor.stop()
    }

    // La usa MenuBarView cuando el usuario pulsa "Mostrar historial" en el menú
    func showHistoryPanel() {
        panelController?.show()
    }
}
