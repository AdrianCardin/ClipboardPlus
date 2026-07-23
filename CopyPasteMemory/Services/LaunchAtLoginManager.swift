//
//  LaunchAtLoginManager.swift
//  CopyPasteMemory
//

import ServiceManagement
import Combine

// SMAppService es la API moderna de macOS (desde macOS 13) para registrar
// una app como "elemento de inicio de sesión" — que se abra sola al
// arrancar el Mac. Sustituye a mecanismos más antiguos (SMLoginItemSetEnabled,
// una app auxiliar separada...) y, para el caso más simple — registrar la
// PROPIA app principal, que es justo nuestro caso —, no necesita ningún
// permiso ni entitlement especial, ni siquiera con el sandbox activado.
final class LaunchAtLoginManager: ObservableObject {
    // Lo que se ve en el Toggle del menú: activado/desactivado
    @Published private(set) var isEnabled: Bool

    init() {
        // .mainApp.status nos dice el estado actual, consultando al sistema
        // (no es algo que nosotros guardemos, siempre preguntamos a macOS).
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    // La llama el Toggle del menú al activarlo/desactivarlo.
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Si algo falla (raro, pero posible), no rompemos nada — nos
            // limitamos a reflejar el estado real que quede en el sistema.
        }

        // Volvemos a preguntar el estado real después de intentar el cambio,
        // en vez de asumir que ha ido bien.
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled

        // A veces macOS exige que el usuario apruebe manualmente el inicio
        // automático desde Ajustes del Sistema (la primera vez, o si el
        // usuario lo había bloqueado antes). En ese caso, le llevamos
        // directamente al sitio exacto donde tiene que aprobarlo.
        if status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
