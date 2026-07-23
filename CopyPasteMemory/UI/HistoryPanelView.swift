//
//  HistoryPanelView.swift
//  CopyPasteMemory
//

import SwiftUI

// La vista SwiftUI que se muestra DENTRO del NSPanel (ver HistoryPanelController).
// Dibuja la lista del historial y gestiona la navegación con teclado.
struct HistoryPanelView: View {
    // @ObservedObject: esta vista "observa" el store, así que cada vez que
    // `items` cambie (nueva copia, borrado, pin/despin...) la vista se
    // redibuja sola. No usamos @StateObject porque no somos dueños del
    // store — lo crea y mantiene vivo AppDelegate, aquí solo lo tomamos prestado.
    @ObservedObject var store: ClipboardHistoryStore

    // Closure que llamamos para pedirle al controller que cierre el panel
    // (al seleccionar un item, o al pulsar Escape)
    var onDismiss: () -> Void

    // @State: variable propia de esta vista, para recordar qué fila está
    // resaltada mientras navegas con las flechas del teclado
    @State private var selectedID: ClipboardItem.ID?

    private var unpinnedCount: Int { store.items.filter { !$0.isPinned }.count }
    private var pinnedCount: Int { store.items.count - unpinnedCount }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(width: 360, height: 420)
        .background(.regularMaterial) // efecto "cristal esmerilado" típico de macOS
        .onAppear {
            // Al abrir el panel, seleccionamos por defecto el primer item (el más reciente)
            selectedID = store.items.first?.id
        }
        // Los modificadores .onKeyPress capturan teclas concretas mientras
        // el panel tiene el foco (gracias al truco de KeyablePanel)
        .onKeyPress(.escape) {
            onDismiss()
            return .handled // "ya me he encargado yo de esta tecla"
        }
        .onKeyPress(.return) {
            selectCurrent()
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        // .alert(item:) se muestra automáticamente cuando store.pinError deja
        // de ser nil, y SwiftUI se encarga de volver a ponerlo a nil solo
        // cuando el usuario cierra la alerta (pulsando "Vale").
        .alert(item: $store.pinError) { error in
            Alert(
                title: Text("No se puede pinear"),
                message: Text(error.errorDescription ?? ""),
                dismissButton: .default(Text("Vale"))
            )
        }
    }

    private var header: some View {
        HStack {
            Text("Historial de portapapeles")
                .font(.headline)
            Spacer()
            Text(pinnedCount > 0 ? "\(unpinnedCount)/25 · \(pinnedCount) 📌" : "\(unpinnedCount)/25")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    // Lo que se ve si todavía no se ha copiado nada
    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Copia algo para empezar")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var list: some View {
        // ScrollViewReader nos deja hacer scroll automático hasta una fila
        // concreta (proxy.scrollTo) cuando cambia la selección por teclado
        ScrollViewReader { proxy in
            ScrollView {
                // LazyVStack: solo crea las filas que están visibles en pantalla,
                // más eficiente que VStack si la lista fuera larga
                LazyVStack(spacing: 2) {
                    ForEach(store.items) { item in
                        HistoryRowView(
                            item: item,
                            isSelected: item.id == selectedID,
                            onSelect: { select(item) },
                            onTogglePin: { store.togglePin(item) }
                        )
                        .id(item.id) // necesario para que scrollTo sepa a qué fila ir
                    }
                }
                .padding(6)
            }
            // Cada vez que `selectedID` cambia, desplazamos el scroll hasta esa fila
            .onChange(of: selectedID) { _, newValue in
                guard let newValue else { return }
                proxy.scrollTo(newValue, anchor: .center)
            }
        }
    }

    // Mueve la selección hacia arriba (-1) o abajo (+1), sin salirse de los límites
    private func moveSelection(by offset: Int) {
        guard !store.items.isEmpty else { return }
        let currentIndex = store.items.firstIndex(where: { $0.id == selectedID }) ?? 0
        let newIndex = min(max(currentIndex + offset, 0), store.items.count - 1)
        selectedID = store.items[newIndex].id
    }

    // Al pulsar Enter: selecciona el item actualmente resaltado
    private func selectCurrent() {
        guard let selectedID, let item = store.items.first(where: { $0.id == selectedID }) else { return }
        select(item)
    }

    // Acción común a "clic en una fila" y "Enter": restaurar ese item al
    // portapapeles y cerrar el panel
    private func select(_ item: ClipboardItem) {
        store.selectAndRestore(item)
        onDismiss()
    }
}
