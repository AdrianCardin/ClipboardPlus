//
//  HotKeyManager.swift
//  CopyPasteMemory
//

import Carbon.HIToolbox
import AppKit

// Carbon es un framework muy antiguo de macOS (de antes de Swift, incluso de
// antes de Objective-C ser lo habitual). Sigue siendo, hoy en día, la forma
// recomendada de registrar un atajo de teclado GLOBAL (que funcione aunque
// nuestra app no tenga el foco) sin pedir permisos especiales de Accesibilidad,
// a diferencia de otras APIs más modernas como NSEvent.addGlobalMonitor.
final class HotKeyManager {
    // Un identificador de 4 caracteres que "firma" nuestro atajo, para poder
    // reconocerlo si en el futuro registrásemos más de uno. Ver fourCharCode() abajo.
    private static let signature: FourCharCode = fourCharCode("CPMk")

    private let keyCode: UInt32     // qué tecla (ej. la V)
    private let modifiers: UInt32   // qué teclas modificadoras (Cmd, Option...)
    private let hotKeyID = EventHotKeyID(signature: HotKeyManager.signature, id: 1)

    // "Handles" que Carbon nos da al registrar el atajo; los necesitamos
    // guardados para poder des-registrar todo correctamente al salir.
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    // Closure que se ejecuta cuando el usuario pulsa el atajo.
    var onHotKeyPressed: (() -> Void)?

    // Por defecto: Cmd+Option+V.
    // kVK_ANSI_V = código de la tecla V en teclados ANSI (EE.UU./España estándar)
    // cmdKey / optionKey son "banderas de bits" que se combinan con | (OR)
    init(keyCode: UInt32 = UInt32(kVK_ANSI_V), modifiers: UInt32 = UInt32(cmdKey | optionKey)) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    func register() {
        // Describe QUÉ tipo de evento queremos escuchar: "se ha pulsado un hotkey"
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        // InstallEventHandler es una función de C, así que el callback que le
        // pasamos también tiene que "parecer" una función de C (no puede
        // capturar variables Swift directamente como haría una closure normal).
        // Por eso usamos el truco de Unmanaged más abajo para pasar `self`.
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData -> OSStatus in
                guard let eventRef, let userData else { return noErr }

                // Recuperamos el ID del hotkey que disparó este evento...
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                // ...y comprobamos que es el nuestro (por si hubiera más de uno)
                guard hotKeyID.signature == HotKeyManager.signature else { return noErr }

                // `userData` es un puntero "en crudo" a nuestra instancia de
                // HotKeyManager (se lo pasamos nosotros mismos unas líneas más
                // abajo). Unmanaged.fromOpaque() lo convierte de vuelta a un
                // objeto Swift normal para poder llamar a su closure.
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.onHotKeyPressed?()
                return noErr
            },
            1,
            &eventType,
            // Aquí "empaquetamos" self como puntero en crudo para pasárselo
            // a la función de C de arriba (es la otra mitad del truco).
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        // Y finalmente registramos el atajo en sí: tecla + modificadores + id
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    // Se llama al cerrar la app, para liberar el atajo y el handler
    // (si no, el atajo podría quedar "enganchado" a nivel del sistema).
    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }
}

// Convierte un texto de 4 letras (ej. "CPMk") en un número de 32 bits,
// tomando cada carácter como un byte y desplazándolos uno tras otro.
// Es el formato que Carbon espera para identificar cosas como nuestro hotkey.
private func fourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for byte in string.utf8 {
        result = (result << 8) + FourCharCode(byte)
    }
    return result
}
