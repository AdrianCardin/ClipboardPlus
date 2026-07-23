//
//  ClipboardItem.swift
//  CopyPasteMemory
//

import Foundation
import CryptoKit

enum ClipboardContent: Equatable {
    case text(String)
    case image(Data)

    var hashDigest: String {
        let bytes: Data
        switch self {
        case .text(let string):
            bytes = Data(string.utf8)
        case .image(let data):
            bytes = data
        }
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let content: ClipboardContent
    let timestamp: Date
    let contentHash: String

    init(content: ClipboardContent, timestamp: Date = Date()) {
        self.id = UUID()
        self.content = content
        self.timestamp = timestamp
        self.contentHash = content.hashDigest
    }
}
