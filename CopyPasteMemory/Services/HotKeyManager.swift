//
//  HotKeyManager.swift
//  CopyPasteMemory
//

import Carbon.HIToolbox
import AppKit

/// Registers a system-wide keyboard shortcut via the Carbon Event Manager.
/// Works fine under App Sandbox and needs no Accessibility permission —
/// unlike NSEvent's global monitor APIs.
final class HotKeyManager {
    private static let signature: FourCharCode = fourCharCode("CPMk")

    private let keyCode: UInt32
    private let modifiers: UInt32
    private let hotKeyID = EventHotKeyID(signature: HotKeyManager.signature, id: 1)

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    var onHotKeyPressed: (() -> Void)?

    /// Defaults to Cmd+Option+V (Cmd+V itself belongs to the system/foreground app).
    init(keyCode: UInt32 = UInt32(kVK_ANSI_V), modifiers: UInt32 = UInt32(cmdKey | optionKey)) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData -> OSStatus in
                guard let eventRef, let userData else { return noErr }

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
                guard hotKeyID.signature == HotKeyManager.signature else { return noErr }

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.onHotKeyPressed?()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

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

private func fourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for byte in string.utf8 {
        result = (result << 8) + FourCharCode(byte)
    }
    return result
}
