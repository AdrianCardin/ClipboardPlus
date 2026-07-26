//
//  ClipboardItemTests.swift
//  CopyPasteMemoryUnitTests
//

import Testing
import Foundation
@testable import ClipboardPlus

// @testable import nos deja ver también los tipos "internos" (sin `public`)
// de la app, como si estos tests formaran parte del propio módulo.
//
// @MainActor: el resto del proyecto tiene SWIFT_DEFAULT_ACTOR_ISOLATION =
// MainActor, así que estos tipos ya viven en el hilo principal; aislamos
// los tests igual para evitar fricciones de concurrencia al usarlos.
@Suite("Clipboard Item")
@MainActor
struct ClipboardItemTests {

    @Test("Mismo texto produce el mismo hash")
    func sameTextProducesTheSameHash() {
        let a = ClipboardContent.text("hola mundo")
        let b = ClipboardContent.text("hola mundo")
        #expect(a.hashDigest == b.hashDigest)
    }

    @Test("Diferente texto produce hashes diferentes")
    func differentTextProducesDifferentHashes() {
        let a = ClipboardContent.text("hola")
        let b = ClipboardContent.text("adiós")
        #expect(a.hashDigest != b.hashDigest)
    }

    @Test("Mismos bytes de imagen producen el mismo hash")
    func sameImageBytesProduceTheSameHash() {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let a = ClipboardContent.image(data)
        let b = ClipboardContent.image(data)
        #expect(a.hashDigest == b.hashDigest)
    }

    @Test("Texto e imagen con bytes equivalentes producen hashes diferentes")
    func textAndImageWithEquivalentBytesStillDiffer() {
        // Aunque los bytes "parezcan" los mismos, .text y .image son casos
        // distintos del enum — no deberían mezclarse nunca al deduplicar.
        let asText = ClipboardContent.text("abc")
        let asImage = ClipboardContent.image(Data("abc".utf8))
        #expect(asText.hashDigest != asImage.hashDigest)
    }

    @Test("Cada item obtiene su propio ID único")
    func eachItemGetsItsOwnUniqueID() {
        // Dos items con el MISMO contenido siguen siendo entidades distintas
        // (cada uno con su propio UUID) — es el hash, no el id, lo que se
        // usa para detectar duplicados en ClipboardHistoryStore.
        let item1 = ClipboardItem(content: .text("igual"))
        let item2 = ClipboardItem(content: .text("igual"))

        #expect(item1.id != item2.id)
        #expect(item1.contentHash == item2.contentHash)
    }

    @Test("Items nuevos comienzan sin pinear")
    func newItemsStartUnpinned() {
        let item = ClipboardItem(content: .text("algo"))
        #expect(item.isPinned == false)
    }
    
    // MARK: - Tests adicionales para casos edge
    
    @Test("Imagen vacía produce un hash válido")
    func emptyImageProducesValidHash() {
        let emptyData = Data()
        let content = ClipboardContent.image(emptyData)
        #expect(content.hashDigest.count > 0)
    }
    
    @Test("Texto vacío produce un hash válido")
    func emptyTextProducesValidHash() {
        let content = ClipboardContent.text("")
        #expect(content.hashDigest.count > 0)
    }
    
    @Test("Hashes son determinísticos", arguments: [
        "hola mundo",
        "texto con emoji 🎉",
        "",
        String(repeating: "a", count: 1000)
    ])
    func hashesAreDeterministic(text: String) {
        let first = ClipboardContent.text(text)
        let second = ClipboardContent.text(text)
        
        // Mismo contenido debe producir exactamente el mismo hash
        #expect(first.hashDigest == second.hashDigest)
    }
}
