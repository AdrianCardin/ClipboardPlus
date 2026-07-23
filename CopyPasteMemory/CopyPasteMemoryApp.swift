//
//  CopyPasteMemoryApp.swift
//  CopyPasteMemory
//
//  Created by Adrián Cardín Lozano on 23/07/2026.
//

import SwiftUI

@main
struct CopyPasteMemoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("CopyPasteMemory", systemImage: "doc.on.clipboard") {
            MenuBarView(store: appDelegate.historyStore)
        }
    }
}
