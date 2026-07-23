//
//  ClipboardItemTests.swift
//  CopyPasteMemoryUnitTests
//

import Testing
import Foundation
@testable import CopyPasteMemory

// @testable import nos deja ver también los tipos "internos" (sin `public`)
// de la app, como si estos tests formaran parte del propio módulo.
//
// @MainActor: el resto del proyecto tiene SWIFT_DEFAULT_ACTOR_ISOLATION =
// MainActor, así que estos tipos ya viven en el hilo principal; aislamos
// los tests igual para evitar fricciones de concurrencia al usarlos.
@MainActor
struct ClipboardItemTests {

    @Test func sameTextProducesTheSameHash() {
        let a = ClipboardContent.text("hola mundo")
        let b = ClipboardContent.text("hola mundo")
        #expect(a.hashDigest == b.hashDigest)
    }

    @Test func differentTextProducesDifferentHashes() {
        let a = ClipboardContent.text("hola")
        let b = ClipboardContent.text("adiós")
        #expect(a.hashDigest != b.hashDigest)
    }

    @Test func sameImageBytesProduceTheSameHash() {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let a = ClipboardContent.image(data)
        let b = ClipboardContent.image(data)
        #expect(a.hashDigest == b.hashDigest)
    }

    @Test func textAndImageWithEquivalentBytesStillDiffer() {
        // Aunque los bytes "parezcan" los mismos, .text y .image son casos
        // distintos del enum — no deberían mezclarse nunca al deduplicar.
        let asText = ClipboardContent.text("abc")
        let asImage = ClipboardContent.image(Data("abc".utf8))
        #expect(asText.hashDigest != asImage.hashDigest)
    }

    @Test func eachItemGetsItsOwnUniqueID() {
        // Dos items con el MISMO contenido siguen siendo entidades distintas
        // (cada uno con su propio UUID) — es el hash, no el id, lo que se
        // usa para detectar duplicados en ClipboardHistoryStore.
        let item1 = ClipboardItem(content: .text("igual"))
        let item2 = ClipboardItem(content: .text("igual"))

        #expect(item1.id != item2.id)
        #expect(item1.contentHash == item2.contentHash)
    }

    @Test func newItemsStartUnpinned() {
        let item = ClipboardItem(content: .text("algo"))
        #expect(item.isPinned == false)
    }
}
