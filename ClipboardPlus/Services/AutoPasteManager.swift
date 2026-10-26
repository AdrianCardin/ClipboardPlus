//
//  AutoPasteManager.swift
//  ClipboardPlus
//

import AppKit
import ApplicationServices
import Combine
import os

// Opción "Pegar automáticamente" (desactivada por defecto). Si está activa,
// al elegir un item del panel, además de copiarlo, lo pegamos directamente
// en la app donde estabas — como el Win+V de Windows.
//
// Para "pegar" simulamos que el usuario pulsa Cmd+V. macOS solo deja que una
// app simule teclas si el usuario le ha dado el permiso de ACCESIBILIDAD
// (Ajustes del Sistema → Privacidad y seguridad → Accesibilidad). Sin ese
// permiso, la app sigue funcionando como siempre: solo copia.
final class AutoPasteManager: ObservableObject {
    // Lo que se ve en el Toggle del menú: activado/desactivado
    @Published private(set) var isEnabled: Bool

    // A diferencia de "Abrir al iniciar sesión" (que se pregunta a macOS),
    // esta preferencia es nuestra, así que la guardamos en UserDefaults
    // para que se recuerde entre reinicios de la app.
    private static let defaultsKey = "autoPasteEnabled"

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.defaultsKey)
    }

    // La llama el Toggle del menú al activarlo/desactivarlo.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.defaultsKey)

        // Al activarlo, si todavía no tenemos el permiso, se lo pedimos:
        // con la opción "prompt", macOS muestra su propio diálogo con un
        // botón que lleva directo a Ajustes del Sistema → Accesibilidad.
        if enabled && !Self.hasPermission {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            // Petición específica para "simular teclas", que es lo único que
            // hacemos. Es la vía que macOS contempla para apps con sandbox.
            CGRequestPostEventAccess()
        }
    }

    // Nos basta con cualquiera de los dos: Accesibilidad completa, o solo el
    // permiso de enviar eventos de teclado (ambos se conceden desde la misma
    // lista de Ajustes del Sistema → Privacidad y seguridad → Accesibilidad).
    private static var hasPermission: Bool {
        AXIsProcessTrusted() || CGPreflightPostEventAccess()
    }

    // Mensajes de diagnóstico: se pueden ver en la app Consola, o en Terminal con
    // log show --last 5m --predicate 'category == "AutoPaste"'
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ClipboardPlus", category: "AutoPaste")

    // La llama HistoryPanelController justo después de copiar el item elegido,
    // cerrar el panel y devolverle el foco a la app anterior. `targetApp` es
    // la app que estaba delante antes de abrir el panel — ahí queremos pegar.
    func pasteIfEnabled(into targetApp: NSRunningApplication?) {
        // Si la opción está apagada, o el usuario no ha dado (o ha quitado)
        // el permiso, no hacemos nada: el item ya está copiado y se puede
        // pegar a mano con Cmd+V, como siempre.
        guard isEnabled else { return }
        guard Self.hasPermission else {
            logger.notice("Sin permiso de Accesibilidad: solo se copia")
            return
        }
        guard let targetApp else {
            logger.notice("No hay app anterior en la que pegar")
            return
        }

        waitUntilFrontmost(targetApp, attemptsLeft: 20)
    }

    // El cambio de app no es instantáneo: si enviamos el Cmd+V antes de que
    // la app anterior esté delante de verdad, se pierde. Así que comprobamos
    // cada 25 ms (hasta ~0,5 s) si ya lo está, y entonces pegamos.
    private func waitUntilFrontmost(_ targetApp: NSRunningApplication, attemptsLeft: Int) {
        if NSWorkspace.shared.frontmostApplication == targetApp {
            logger.notice("Pegando en \(targetApp.localizedName ?? "?", privacy: .public)")
            // Un pequeño margen extra para que la app vuelva a poner el foco
            // en su campo de texto antes de recibir el Cmd+V
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                Self.postCommandV()
            }
        } else if attemptsLeft > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { [weak self] in
                self?.waitUntilFrontmost(targetApp, attemptsLeft: attemptsLeft - 1)
            }
        } else {
            let frontmost = NSWorkspace.shared.frontmostApplication?.localizedName ?? "ninguna"
            logger.notice("\(targetApp.localizedName ?? "?", privacy: .public) no llegó a ponerse delante (delante está: \(frontmost, privacy: .public)); no se pega")
        }
    }

    // Simula pulsar y soltar Cmd+V, como si lo hiciera el usuario.
    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // código de la tecla "V" en el teclado (kVK_ANSI_V)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
