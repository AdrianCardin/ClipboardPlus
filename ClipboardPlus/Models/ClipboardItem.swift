//
//  ClipboardItem.swift
//  CopyPasteMemory
//

import Foundation
import CryptoKit

// Un elemento copiado puede ser texto o imagen. Un "enum con valor asociado"
// es como un "case" que además lleva sus propios datos pegados:
// - .text lleva un String
// - .image lleva un Data (los bytes en crudo de la imagen, en formato PNG)
enum ClipboardContent: Equatable {
    case text(String)
    case image(Data)

    // Calcula un "hash" (huella digital) del contenido: una cadena corta que
    // identifica de forma (casi) única esos bytes. Nos sirve para comparar
    // dos elementos sin tener que comparar el texto/imagen completo cada vez,
    // y para detectar duplicados (ver ClipboardHistoryStore.add).
    var hashDigest: String {
        // Empezamos siempre por un "prefijo" que identifica el tipo de caso
        // (texto o imagen) antes de añadir los bytes de verdad. Sin esto, un
        // texto y una imagen que tuvieran EXACTAMENTE los mismos bytes en
        // crudo generarían el mismo hash, aunque sean cosas distintas — un
        // test lo detectó (textAndImageWithEquivalentBytesStillDiffer).
        var bytes: Data
        switch self {
        case .text(let string):
            bytes = Data("text:".utf8)
            // Convertimos el String a Data (sus bytes en UTF-8) para poder hashearlo
            bytes.append(Data(string.utf8))
        case .image(let data):
            bytes = Data("image:".utf8)
            bytes.append(data)
        }
        // SHA256 genera 32 bytes; los convertimos a texto hexadecimal (ej. "a3f9c1...")
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}

// Representa una entrada del historial: el contenido en sí, más metadatos.
// Identifiable es un protocolo de SwiftUI: con un campo `id`, las listas
// (ForEach, List) saben distinguir cada fila sin que se lo digamos explícitamente.
struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let content: ClipboardContent
    let timestamp: Date
    let contentHash: String

    // `var` (no `let`): a diferencia de los demás campos, esto SÍ puede
    // cambiar después de crear el item (al pinear/despinear desde el panel).
    var isPinned: Bool

    // Inicializador "normal": se usa cuando algo se acaba de copiar. Genera
    // automáticamente un id único (UUID), toma la fecha actual, y calcula
    // el hash una sola vez (no en cada comparación). Nace siempre sin pinear.
    init(content: ClipboardContent, timestamp: Date = Date()) {
        self.id = UUID()
        self.content = content
        self.timestamp = timestamp
        self.contentHash = content.hashDigest
        self.isPinned = false
    }

    // Segundo inicializador: se usa SOLO al reconstruir un item pineado que
    // venía guardado en disco/Keychain (ver PinnedItemStore.loadAll()). Aquí
    // SÍ recibimos el id y la fecha desde fuera, para conservar los
    // originales en vez de generar unos nuevos cada vez que arranca la app.
    init(id: UUID, content: ClipboardContent, timestamp: Date, isPinned: Bool) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.contentHash = content.hashDigest
        self.isPinned = isPinned
    }
}
