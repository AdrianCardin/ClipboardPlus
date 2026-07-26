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
@Suite("Clipboard History Store")
@MainActor
struct ClipboardHistoryStoreTests {
    
    // Constantes para evitar números mágicos
    private let maxHistorySize = 25
    private let maxPinSizeBytes = 100_000

    @Test("Añadir un item nuevo lo pone primero en la lista")
    func addingANewItemPutsItFirst() {
        let store = ClipboardHistoryStore()
        store.add(.text("primero"))
        store.add(.text("segundo"))

        #expect(store.items.first?.content == .text("segundo"))
    }

    @Test("Añadir contenido duplicado lo mueve al frente sin duplicar")
    func addingDuplicateContentMovesItToFrontInsteadOfDuplicating() {
        let store = ClipboardHistoryStore()
        let countBefore = store.items.count

        store.add(.text("dedupe-a"))
        store.add(.text("dedupe-b"))
        store.add(.text("dedupe-a")) // mismo contenido que el primero

        // Solo se han añadido 2 items nuevos de verdad, no 3
        #expect(store.items.count == countBefore + 2)
        #expect(store.items.first?.content == .text("dedupe-a"))
    }

    @Test("El historial mantiene máximo 25 items no pineados")
    func historyIsCappedAt25UnpinnedItems() {
        let store = ClipboardHistoryStore()
        let pinnedAtStart = store.items.filter(\.isPinned).count

        for i in 0..<30 {
            store.add(.text("cap-test-\(i)"))
        }

        // El límite de 25 aplica solo a los NO pineados; si ya hubiera algún
        // pin real de antes, se suma aparte.
        #expect(store.items.count == maxHistorySize + pinnedAtStart)
        // Los 5 primeros (los más antiguos de esta tanda) deben haber caído fuera
        #expect(!store.items.contains { $0.content == .text("cap-test-0") })
        // El último añadido, en cambio, debe seguir ahí
        #expect(store.items.contains { $0.content == .text("cap-test-29") })
    }

    @Test("Toggle pin rechaza texto que excede el límite de tamaño")
    func togglePinRejectsTextOverTheSizeLimit() {
        let store = ClipboardHistoryStore()
        let hugeText = String(repeating: "a", count: maxPinSizeBytes + 50_000) // > 100 KB
        store.add(.text(hugeText))

        guard let item = store.items.first else {
            Issue.record("Se esperaba encontrar el item recién añadido")
            return
        }

        store.togglePin(item)

        #expect(store.pinError == .tooLarge)
        #expect(store.items.first?.isPinned == false)
    }

    @Test("Toggle pin acepta y persiste un item de texto pequeño")
    func togglePinAcceptsAndPersistsASmallTextItem() {
        // Este test SÍ llega a escribir en el Llavero real (no hay mock),
        // así que despineamos al final para no dejar basura en tu Mac.
        let store = ClipboardHistoryStore()
        store.add(.text("nota de test para pinear"))

        guard let item = store.items.first else {
            Issue.record("Se esperaba encontrar el item recién añadido")
            return
        }

        defer {
            // Limpieza garantizada, incluso si falla el test
            if let pinned = store.items.first(where: { $0.isPinned }) {
                store.togglePin(pinned)
            }
        }

        store.togglePin(item)

        #expect(store.pinError == nil)
        #expect(store.items.first?.isPinned == true)
    }

    @Test("Items pineados sobreviven al límite de 25 items")
    func pinnedItemsSurviveThe25ItemCap() {
        let store = ClipboardHistoryStore()
        store.add(.text("no me toques que estoy pineado"))

        guard let toPin = store.items.first else {
            Issue.record("Se esperaba encontrar el item recién añadido")
            return
        }
        
        defer {
            // Limpieza garantizada
            if let pinned = store.items.first(where: { $0.content == .text("no me toques que estoy pineado") }) {
                store.togglePin(pinned)
            }
        }
        
        store.togglePin(toPin)
        #expect(store.pinError == nil)

        for i in 0..<30 {
            store.add(.text("relleno-\(i)"))
        }

        #expect(store.items.contains {
            $0.content == .text("no me toques que estoy pineado") && $0.isPinned
        })
    }

    @Test("Limpiar historial mantiene items pineados pero elimina el resto")
    func clearHistoryKeepsPinnedItemsButRemovesTheRest() {
        let store = ClipboardHistoryStore()
        store.add(.text("se queda porque está pineado"))

        guard let toPin = store.items.first else {
            Issue.record("Se esperaba encontrar el item recién añadido")
            return
        }
        
        defer {
            // Limpieza garantizada
            if let pinned = store.items.first(where: { $0.content == .text("se queda porque está pineado") }) {
                store.togglePin(pinned)
            }
        }
        
        store.togglePin(toPin)
        #expect(store.pinError == nil)

        store.add(.text("se borra al vaciar"))
        store.clearHistory()

        #expect(store.items.contains { $0.content == .text("se queda porque está pineado") })
        #expect(!store.items.contains { $0.content == .text("se borra al vaciar") })
        // Tras vaciar, no debería quedar NINGÚN item sin pinear
        #expect(store.items.allSatisfy { $0.isPinned })
    }
    
    // MARK: - Tests adicionales para casos edge
    
    @Test("Texto vacío se puede añadir al historial")
    func emptyTextCanBeAdded() {
        let store = ClipboardHistoryStore()
        store.add(.text(""))
        #expect(store.items.first?.content == .text(""))
    }
    
    @Test("Toggle pin dos veces vuelve al estado original")
    func togglePinTwiceReturnsToOriginalState() {
        let store = ClipboardHistoryStore()
        store.add(.text("toggle-test"))
        
        guard let item = store.items.first else {
            Issue.record("Se esperaba encontrar el item recién añadido")
            return
        }
        
        defer {
            // Asegurar limpieza
            if let maybePin = store.items.first(where: { $0.content == .text("toggle-test") && $0.isPinned }) {
                store.togglePin(maybePin)
            }
        }
        
        // Primera vez: pinear
        store.togglePin(item)
        #expect(store.items.first?.isPinned == true)
        
        // Segunda vez: despinear
        if let pinned = store.items.first {
            store.togglePin(pinned)
        }
        #expect(store.items.first?.isPinned == false)
    }
}
