//
//  NotesViewModel.swift
//  TapBack Command
//

import Foundation
import SwiftUI

@MainActor
final class NotesViewModel: ObservableObject {

    @Published private(set) var notes: [Note] = []

    private let storage = StorageService.shared

    init() { load() }

    func load() {
        notes = storage.loadNotes().sorted { $0.createdAt > $1.createdAt }
    }

    func add(_ note: Note) {
        notes.insert(note, at: 0)
        persist()
    }

    func delete(_ note: Note) {
        storage.deleteAudio(named: note.audioFileName)
        notes.removeAll { $0.id == note.id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        offsets.map { notes[$0] }.forEach { storage.deleteAudio(named: $0.audioFileName) }
        notes.remove(atOffsets: offsets)
        persist()
    }

    private func persist() { storage.saveNotes(notes) }
}
