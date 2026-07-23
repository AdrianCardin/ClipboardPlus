//
//  PinnedItemStore.swift
//  CopyPasteMemory
//

import Foundation
import Security

// El resto del historial vive solo en RAM (se pierde al cerrar la app, a
// propósito, ver ClipboardHistoryStore). Los items "pineados" son la
// excepción: el usuario ha decidido explícitamente conservarlos, así que
// esta clase los guarda de verdad en disco para que sobrevivan a un reinicio.
//
// Repartimos el guardado en tres sitios distintos, cada uno para lo suyo:
// - El TEXTO va al Llavero de macOS (Keychain): lo cifra y protege el propio
//   sistema operativo, igual que hace con tus contraseñas guardadas.
// - Las IMÁGENES van a archivos normales dentro de la carpeta privada de la
//   app (Keychain no está pensado para guardar binarios grandes).
// - Un "manifiesto" en JSON con SOLO metadatos (id, tipo, fecha — nunca el
//   contenido en sí) nos dice qué hay pineado, para poder reconstruir la
//   lista al arrancar sin tener que "adivinar" qué buscar en el Llavero.
final class PinnedItemStore {
    // Lo que guardamos en el manifiesto: nunca datos sensibles, solo lo
    // necesario para saber "qué hay" y "dónde ir a buscar el contenido real".
    private struct ManifestEntry: Codable {
        let id: UUID
        let kind: Kind
        let timestamp: Date

        enum Kind: String, Codable {
            case text, image
        }
    }

    private let manifestURL: URL
    private let imagesDirectoryURL: URL
    // "Service" es como una etiqueta que agrupa nuestros items dentro del
    // Llavero, para no mezclarlos con los de otras apps.
    private let keychainService = "com.acl.CopyPasteMemory.pinned-text"

    init() {
        // applicationSupportDirectory, dentro de una app con sandbox, apunta
        // a una carpeta PRIVADA de esta app (nadie más puede leerla sin más):
        // ~/Library/Containers/<bundle-id>/Data/Library/Application Support/
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let baseURL = appSupport.appendingPathComponent("CopyPasteMemory", isDirectory: true)
        manifestURL = baseURL.appendingPathComponent("pinned-manifest.json")
        imagesDirectoryURL = baseURL.appendingPathComponent("PinnedImages", isDirectory: true)

        // Nos aseguramos de que la carpeta existe antes de intentar escribir en ella
        try? FileManager.default.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
    }

    // MARK: - Guardar / borrar un pin

    // Devuelve `true` solo si de verdad se guardó. Antes esta función no
    // devolvía nada y usaba `try?` para ignorar cualquier fallo — eso
    // significaba que si el Llavero o la escritura del archivo fallaban por
    // el motivo que fuera (permiso denegado, disco lleno, Llavero
    // bloqueado...), la app se quedaba pensando que el pin se había guardado
    // bien, sin avisar a nadie. Ahora comprobamos el resultado real y solo
    // anotamos el item en el manifiesto si el contenido se guardó de verdad.
    @discardableResult
    func save(_ item: ClipboardItem) -> Bool {
        let succeeded: Bool
        switch item.content {
        case .text(let string):
            succeeded = saveTextToKeychain(id: item.id, text: string)
        case .image(let data):
            succeeded = saveImageToFile(id: item.id, data: data)
        }

        // Si el contenido no se guardó, no tiene sentido anotarlo en el
        // manifiesto como si fuera un pin válido — quedaría una entrada
        // "fantasma" que loadAll() nunca podría reconstruir.
        guard succeeded else { return false }

        addToManifest(item)
        return true
    }

    func remove(id: UUID) {
        deleteTextFromKeychain(id: id)
        try? FileManager.default.removeItem(at: imageFileURL(for: id))
        removeFromManifest(id: id)
    }

    // MARK: - Cargar todo al arrancar la app

    func loadAll() -> [ClipboardItem] {
        readManifest().compactMap { entry in
            switch entry.kind {
            case .text:
                // Si por lo que sea no encontramos el texto en el Llavero
                // (ej. lo borraron a mano), descartamos esa entrada en vez
                // de crear un item "roto"
                guard let text = readTextFromKeychain(id: entry.id) else { return nil }
                return ClipboardItem(id: entry.id, content: .text(text), timestamp: entry.timestamp, isPinned: true)
            case .image:
                guard let data = try? Data(contentsOf: imageFileURL(for: entry.id)) else { return nil }
                return ClipboardItem(id: entry.id, content: .image(data), timestamp: entry.timestamp, isPinned: true)
            }
        }
    }

    // MARK: - Manifiesto (solo metadatos, nunca contenido)

    private func addToManifest(_ item: ClipboardItem) {
        var entries = readManifest()
        entries.removeAll { $0.id == item.id } // por si ya existía, evitamos duplicarlo
        let kind: ManifestEntry.Kind = {
            switch item.content {
            case .text: return .text
            case .image: return .image
            }
        }()
        entries.append(ManifestEntry(id: item.id, kind: kind, timestamp: item.timestamp))
        writeManifest(entries)
    }

    private func removeFromManifest(id: UUID) {
        var entries = readManifest()
        entries.removeAll { $0.id == id }
        writeManifest(entries)
    }

    private func readManifest() -> [ManifestEntry] {
        guard let data = try? Data(contentsOf: manifestURL),
              let entries = try? JSONDecoder().decode([ManifestEntry].self, from: data) else {
            return [] // la primera vez que arranca la app, este archivo aún no existe
        }
        return entries
    }

    private func writeManifest(_ entries: [ManifestEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: manifestURL)
    }

    private func imageFileURL(for id: UUID) -> URL {
        imagesDirectoryURL.appendingPathComponent("\(id.uuidString).png")
    }

    // MARK: - Keychain (solo para texto)

    // Guarda (o sobrescribe) el texto de un item en el Llavero. La API de
    // Keychain no es de Swift moderno, es una API de C muy antigua (Security
    // framework): se trabaja con diccionarios "query" describiendo qué
    // queremos hacer, en vez de llamar a métodos normales de un objeto.
    // Devuelve si realmente se guardó (comprobando el código de estado que
    // devuelve SecItemAdd, en vez de darlo por hecho).
    private func saveTextToKeychain(id: UUID, text: String) -> Bool {
        let data = Data(text.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            // kSecAttrAccount identifica el item DENTRO de nuestro "service" —
            // usamos el UUID del ClipboardItem para que cada pin tenga su propia entrada
            kSecAttrAccount as String: id.uuidString
        ]

        // Si ya existía una entrada con este id, la borramos primero.
        // Es más simple que usar SecItemUpdate para este caso de uso.
        // (No comprobamos su resultado: si no existía nada que borrar, este
        // paso "falla" de forma esperada y no es un problema real.)
        SecItemDelete(query as CFDictionary)

        var newItem = query
        newItem[kSecValueData as String] = data
        // WhenUnlockedThisDeviceOnly: solo accesible con el Mac desbloqueado,
        // y (importante) EXCLUIDO de copias de seguridad/iCloud Keychain —
        // no queremos que este texto viaje a otros dispositivos sin que el
        // usuario lo haya pedido explícitamente.
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        // SecItemAdd devuelve un "OSStatus": errSecSuccess (0) si fue bien,
        // o un código de error distinto si algo falló (ej. el usuario denegó
        // el permiso del Llavero, o el propio Llavero está bloqueado/corrupto).
        let status = SecItemAdd(newItem as CFDictionary, nil)
        return status == errSecSuccess
    }

    // Igual que saveTextToKeychain pero para el archivo de imagen: usamos
    // try/catch en vez de `try?` para poder distinguir "se guardó bien" de
    // "falló por lo que sea" (disco lleno, sin permisos de escritura...).
    private func saveImageToFile(id: UUID, data: Data) -> Bool {
        do {
            try data.write(to: imageFileURL(for: id))
            return true
        } catch {
            return false
        }
    }

    private func readTextFromKeychain(id: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true, // "devuélveme los bytes guardados, no solo metadatos"
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteTextFromKeychain(id: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: id.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }
}
