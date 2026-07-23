//
//  HistoryPanelController.swift
//  CopyPasteMemory
//

import AppKit
import SwiftUI

// Se encarga de crear y mostrar/ocultar UNA única ventana flotante (NSPanel)
// que contiene el historial. No usamos una ventana SwiftUI normal porque
// necesitamos que aparezca por encima de CUALQUIER app, incluso si esa app
// está a pantalla completa o en otro "Space" (escritorio virtual) — eso solo
// se consigue con configuración específica de AppKit (ver panelInstance()).
final class HistoryPanelController: NSObject, NSWindowDelegate {
    private let store: ClipboardHistoryStore

    // Empieza en nil: el panel no se crea hasta la primera vez que hace falta
    // (así arrancamos la app más rápido y no gastamos memoria si nunca se abre).
    private var panel: NSPanel?
    private var resignObserver: NSObjectProtocol?

    init(store: ClipboardHistoryStore) {
        self.store = store
    }

    // La llama HotKeyManager cada vez que se pulsa Cmd+Option+V:
    // si está visible lo oculta, si no, lo muestra.
    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        print("🟢 HistoryPanelController.show() llamado")

        // Reafirmamos que nuestra app es "la activa" justo antes de mostrar
        // el panel. Esto es clave cuando se abre desde el menú de la barra
        // de estado: al cerrarse ese menú, macOS le devuelve la actividad a
        // la app anterior, y si no hacemos esto, esa desactivación puede
        // arrastrar consigo al panel recién abierto (le quita el foco justo
        // después de dárselo, y como el panel se autooculta al perder el
        // foco, parece que "no ha pasado nada"). Activarnos aquí evita esa
        // pelea por el foco, tanto si se abre por clic como por atajo.
        NSApp.activate()

        let panel = panelInstance()
        positionNearCursor(panel)
        // orderFrontRegardless: tráelo al frente aunque nuestra app no sea la activa
        panel.orderFrontRegardless()
        // makeKey: dale el foco de teclado, para que las flechas/Enter funcionen
        panel.makeKey()

        print("🟢 tras mostrar -> isVisible=\(panel.isVisible) isKeyWindow=\(panel.isKeyWindow) frame=\(panel.frame)")
    }

    func hide() {
        panel?.orderOut(nil) // "sácalo de la pantalla" (no lo destruye, lo reutilizamos)
    }

    // Crea el panel la primera vez que se necesita; las siguientes veces
    // devuelve el mismo que ya existía.
    private func panelInstance() -> NSPanel {
        if let panel { return panel }

        // NSHostingView es el "puente" que permite meter una vista de SwiftUI
        // (HistoryPanelView) dentro de una ventana de AppKit (NSPanel).
        let hostingView = NSHostingView(
            rootView: HistoryPanelView(store: store, onDismiss: { [weak self] in
                self?.hide()
            })
        )

        // KeyablePanel es nuestra propia subclase (definida abajo del todo)
        let newPanel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            // .nonactivatingPanel: al mostrarse, NO le quita el foco general
            // a la app en la que estabas trabajando (por eso hace falta el
            // truco de canBecomeKey más abajo, si no, no podrías ni navegar
            // con las flechas dentro del panel)
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .floating // por encima de ventanas normales
        // Que aparezca en todos los "Spaces" (escritorios virtuales) y también
        // sobre apps a pantalla completa
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isMovableByWindowBackground = true
        newPanel.hidesOnDeactivate = false
        newPanel.contentView = hostingView
        newPanel.delegate = self

        // Nos suscribimos a "esta ventana ha perdido el foco" para poder
        // cerrarla automáticamente si el usuario hace clic fuera de ella
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: newPanel,
            queue: .main
        ) { [weak self] _ in
            print("🔴 el panel ha perdido el foco (didResignKeyNotification) -> se oculta")
            self?.hide()
        }

        panel = newPanel
        return newPanel
    }

    // Coloca el panel cerca de donde está el cursor del ratón en ese momento,
    // asegurándose de que no se salga de los límites de la pantalla.
    private func positionNearCursor(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        // Buscamos en qué pantalla está el cursor (por si hay varios monitores)
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }

        var origin = NSPoint(
            x: mouseLocation.x - panel.frame.width / 2,
            y: mouseLocation.y - panel.frame.height - 12
        )

        // "Empujamos" el origen para que el panel no quede cortado por el borde
        let screenFrame = screen.visibleFrame
        origin.x = min(max(origin.x, screenFrame.minX), screenFrame.maxX - panel.frame.width)
        origin.y = min(max(origin.y, screenFrame.minY), screenFrame.maxY - panel.frame.height)

        panel.setFrameOrigin(origin)
    }
}

// Un .nonactivatingPanel normalmente NUNCA puede convertirse en la ventana
// "key" (la que recibe el teclado). Sobreescribiendo canBecomeKey a `true`
// lo forzamos a aceptar teclado igualmente, sin perder la ventaja de no
// robarle el foco general a la app en la que estabas.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
