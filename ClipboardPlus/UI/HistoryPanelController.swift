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
    private let autoPasteManager: AutoPasteManager

    // Empieza en nil: el panel no se crea hasta la primera vez que hace falta
    // (así arrancamos la app más rápido y no gastamos memoria si nunca se abre).
    private var panel: NSPanel?
    private var resignObserver: NSObjectProtocol?

    // La app que estaba delante justo antes de abrir el panel: ahí es donde
    // pegamos si "Pegar automáticamente" está activado.
    private var previousApp: NSRunningApplication?

    init(store: ClipboardHistoryStore, autoPasteManager: AutoPasteManager) {
        self.store = store
        self.autoPasteManager = autoPasteManager
    }

    // La llama HotKeyManager cada vez que se pulsa Cmd+Option+V:
    // si está visible lo oculta, si no, lo muestra.
    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            // Desde el atajo NO nos activamos: la app donde estabas sigue
            // siendo la activa (y conserva su foco, p. ej. la barra de
            // direcciones del navegador), así el Cmd+V le llega directamente.
            show(activating: false)
        }
    }

    // `activating`: true solo cuando se abre desde el menú de la barra (ver
    // AppDelegate.showHistoryPanel), por la pelea de foco explicada abajo.
    func show(activating: Bool = true) {
        // Apuntamos qué app estaba delante ANTES de activarnos nosotros
        // (si por lo que sea la de delante ya somos nosotros, mantenemos la
        // que teníamos apuntada de la vez anterior)
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost != NSRunningApplication.current {
            previousApp = frontmost
        }

        // Reafirmamos que nuestra app es "la activa" justo antes de mostrar
        // el panel. Esto es clave cuando se abre desde el menú de la barra
        // de estado: al cerrarse ese menú, macOS le devuelve la actividad a
        // la app anterior, y si no hacemos esto, esa desactivación puede
        // arrastrar consigo al panel recién abierto (le quita el foco justo
        // después de dárselo, y como el panel se autooculta al perder el
        // foco, parece que "no ha pasado nada"). Activarnos aquí evita esa
        // pelea por el foco. Desde el atajo no hace falta: el panel es
        // .nonactivatingPanel y KeyablePanel ya le deja recibir el teclado
        // sin quitarle el foco a la app de debajo.
        if activating {
            NSApp.activate()
        }

        let panel = panelInstance()
        positionNearCursor(panel)
        // orderFrontRegardless: tráelo al frente aunque nuestra app no sea la activa
        panel.orderFrontRegardless()
        // makeKey: dale el foco de teclado, para que las flechas/Enter funcionen
        panel.makeKey()
    }

    func hide() {
        panel?.orderOut(nil) // "sácalo de la pantalla" (no lo destruye, lo reutilizamos)
    }

    // Si el panel se abrió desde el menú, nos hicimos "la app activa" (ver show()). Tras elegir
    // un item, le devolvemos el foco a la app donde estabas, para que el
    // Cmd+V (automático o a mano) le llegue a ella y no a nosotros.
    //
    // Desde macOS 14 la activación es "cooperativa": una app ya no puede
    // ponerse delante cuando quiera, sino que la app activa (nosotros) tiene
    // que CEDERLE el turno (yieldActivation) y luego pedir activarla
    // "de parte nuestra" (activate(from:)). Sin esto, macOS puede ignorar
    // la petición y quedarse sin ninguna app con el foco.
    private func returnFocusToPreviousApp() {
        // Si se abrió con el atajo no llegamos a activarnos: no hay nada que devolver
        guard NSApp.isActive, let previousApp else { return }
        NSApp.yieldActivation(to: previousApp)
        previousApp.activate(from: .current, options: [])
    }

    // Crea el panel la primera vez que se necesita; las siguientes veces
    // devuelve el mismo que ya existía.
    private func panelInstance() -> NSPanel {
        if let panel { return panel }

        // NSHostingView es el "puente" que permite meter una vista de SwiftUI
        // (HistoryPanelView) dentro de una ventana de AppKit (NSPanel).
        let hostingView = NSHostingView(
            rootView: HistoryPanelView(
                store: store,
                onDismiss: { [weak self] in
                    self?.hide()
                },
                // Tras copiar el item elegido: cerramos el panel y, si la
                // opción está activa, lo pegamos en la app anterior
                onItemRestored: { [weak self] in
                    guard let self else { return }
                    self.hide()
                    self.returnFocusToPreviousApp()
                    self.autoPasteManager.pasteIfEnabled(into: self.previousApp)
                }
            )
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
