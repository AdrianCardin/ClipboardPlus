//
//  ClipboardHistoryStoreTests.swift
//  CopyPasteMemoryUnitTests
//

import Testing
@testable import CopyPasteMemory

// Nota importante sobre estos tests: ClipboardHistoryStore usa el Llavero y
// el sistema de archivos REALES de este Mac a través de PinnedItemStore (no
// hay una versión "de mentira" inyectada). Eso significa que, si ya has
// pineado algo antes probando la app a mano, ese pin real seguirá estando
// ahí cuando arranque cada test. Por eso, en vez de asumir "el historial
// empieza vacío", estos tests calculan sus expectativas EN RELACIÓN a lo que
// ya hubiera al principio — así funcionan igual de bien tanto si el
// historial está limpio como si no.
//
// @MainActor: el resto del proyecto tiene SWIFT_DEFAULT_ACTOR_ISOLATION =
// MainActor, así que ClipboardHistoryStore ya vive en el hilo principal;
// aislamos los tests igual para poder llamarlo directamente sin fricciones
// de concurrencia.
@MainActor
struct ClipboardHistoryStoreTests {

    @Test func addingANewItemPutsItFirst() {
        let store = ClipboardHistoryStore()
        store.add(.text("primero"))
        store.add(.text("segundo"))

        #expect(store.items.first?.content == .text("segundo"))
    }

    @Test func addingDuplicateContentMovesItToFrontInsteadOfDuplicating() {
        let store = ClipboardHistoryStore()
        let countBefore = store.items.count

        store.add(.text("dedupe-a"))
        store.add(.text("dedupe-b"))
        store.add(.text("dedupe-a")) // mismo contenido que el primero

        // Solo se han añadido 2 items nuevos de verdad, no 3
        #expect(store.items.count == countBefore + 2)
        #expect(store.items.first?.content == .text("dedupe-a"))
    }

    @Test func historyIsCappedAt25UnpinnedItems() {
        let store = ClipboardHistoryStore()
        let pinnedAtStart = store.items.filter(\.isPinned).count

        for i in 0..<30 {
            store.add(.text("cap-test-\(i)"))
        }

        // El límite de 25 aplica solo a los NO pineados; si ya hubiera algún
        // pin real de antes, se suma aparte.
        #expect(store.items.count == 25 + pinnedAtStart)
        // Los 5 primeros (los más antiguos de esta tanda) deben haber caído fuera
        #expect(!store.items.contains { $0.content == .text("cap-test-0") })
        // El último añadido, en cambio, debe seguir ahí
        #expect(store.items.contains { $0.content == .text("cap-test-29") })
    }

    @Test func togglePinRejectsTextOverTheSizeLimit() {
        let store = ClipboardHistoryStore()
        let hugeText = String(repeating: "a", count: 200_000) // > 100 KB
        store.add(.text(hugeText))

        guard let item = store.items.first else {
            Issue.record("Se esperaba encontrar el item recién añadido")
            return
        }

        store.togglePin(item)

        #expect(store.pinError == .tooLarge)
        #expect(store.items.first?.isPinned == false)
    }

    @Test func togglePinAcceptsAndPersistsASmallTextItem() {
        // Este test SÍ llega a escribir en el Llavero real (no hay mock),
        // así que despineamos al final para no dejar basura en tu Mac.
        let store = ClipboardHistoryStore()
        store.add(.text("nota de test para pinear"))

        guard let item = store.items.first else {
            Issue.record("Se esperaba encontrar el item recién añadido")
            return
        }

        store.togglePin(item)

        #expect(store.pinError == nil)
        #expect(store.items.first?.isPinned == true)

        // Limpieza
        if let pinned = store.items.first {
            store.togglePin(pinned)
        }
    }

    @Test func pinnedItemsSurviveThe25ItemCap() {
        let store = ClipboardHistoryStore()
        store.add(.text("no me toques que estoy pineado"))

        guard let toPin = store.items.first else {
            Issue.record("Se esperaba encontrar el item recién añadido")
            return
        }
        store.togglePin(toPin)
        #expect(store.pinError == nil)

        for i in 0..<30 {
            store.add(.text("relleno-\(i)"))
        }

        #expect(store.items.contains {
            $0.content == .text("no me toques que estoy pineado") && $0.isPinned
        })

        // Limpieza
        if let pinned = store.items.first(where: { $0.content == .text("no me toques que estoy pineado") }) {
            store.togglePin(pinned)
        }
    }

    @Test func clearHistoryKeepsPinnedItemsButRemovesTheRest() {
        let store = ClipboardHistoryStore()
        store.add(.text("se queda porque está pineado"))

        guard let toPin = store.items.first else {
            Issue.record("Se esperaba encontrar el item recién añadido")
            return
        }
        store.togglePin(toPin)
        #expect(store.pinError == nil)

        store.add(.text("se borra al vaciar"))
        store.clearHistory()

        #expect(store.items.contains { $0.content == .text("se queda porque está pineado") })
        #expect(!store.items.contains { $0.content == .text("se borra al vaciar") })
        // Tras vaciar, no debería quedar NINGÚN item sin pinear
        #expect(store.items.allSatisfy { $0.isPinned })

        // Limpieza
        if let pinned = store.items.first(where: { $0.content == .text("se queda porque está pineado") }) {
            store.togglePin(pinned)
        }
    }
}
