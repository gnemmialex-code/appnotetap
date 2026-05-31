//
//  StorageService.swift
//  TapBack Command
//
//  Simple, dependency-free JSON persistence in the app's Documents
//  directory. Chosen over CoreData here for transparency and easy
//  inspection; the API is intentionally small so it can be swapped for a
//  CoreData / SwiftData stack later without touching the view models.
//

import Foundation
import UIKit

final class StorageService {

    static let shared = StorageService()
    private let fm = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        createFoldersIfNeeded()
    }

    // MARK: - Directories

    private var documents: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var audioDirectory: URL { documents.appendingPathComponent(Constants.Storage.audioFolder, isDirectory: true) }
    var imagesDirectory: URL { documents.appendingPathComponent(Constants.Storage.imagesFolder, isDirectory: true) }

    private func createFoldersIfNeeded() {
        for dir in [audioDirectory, imagesDirectory] {
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: - Generic codable load / save

    private func url(for file: String) -> URL { documents.appendingPathComponent(file) }

    private func load<T: Decodable>(_ type: T.Type, from file: String) -> [T] where T: Decodable {
        let fileURL = url(for: file)
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? decoder.decode([T].self, from: data)) ?? []
    }

    private func save<T: Encodable>(_ items: [T], to file: String) {
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: url(for: file), options: [.atomic])
    }

    // MARK: - Notes

    func loadNotes() -> [Note] { load(Note.self, from: Constants.Storage.notesFile) }
    func saveNotes(_ notes: [Note]) { save(notes, to: Constants.Storage.notesFile) }

    // MARK: - Todos

    func loadTodos() -> [Todo] { load(Todo.self, from: Constants.Storage.todosFile) }
    func saveTodos(_ todos: [Todo]) { save(todos, to: Constants.Storage.todosFile) }

    // MARK: - Captures

    func loadCaptures() -> [Capture] { load(Capture.self, from: Constants.Storage.capturesFile) }
    func saveCaptures(_ captures: [Capture]) { save(captures, to: Constants.Storage.capturesFile) }

    // MARK: - Binary assets

    /// Persists a UIImage as JPEG and returns its filename (or nil on failure).
    @discardableResult
    func saveImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        let name = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: imagesDirectory.appendingPathComponent(name), options: [.atomic])
            return name
        } catch {
            return nil
        }
    }

    func image(named name: String) -> UIImage? {
        UIImage(contentsOfFile: imagesDirectory.appendingPathComponent(name).path)
    }

    func audioURL(named name: String) -> URL {
        audioDirectory.appendingPathComponent(name)
    }

    func deleteAudio(named name: String?) {
        guard let name else { return }
        try? fm.removeItem(at: audioURL(named: name))
    }
}
