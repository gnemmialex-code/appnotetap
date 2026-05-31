//
//  Note.swift
//  TapBack Command
//
//  A voice note: original audio (stored on disk by filename), the raw
//  transcript, an automatic summary and an optional structured plan.
//

import Foundation

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var createdAt: Date
    /// Filename (not full path) of the recorded audio inside Documents/Audio.
    var audioFileName: String?
    var transcript: String
    var summary: String
    /// Structured plan produced when the user asks for one ("fais un plan").
    var plan: [String]
    var title: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        audioFileName: String? = nil,
        transcript: String = "",
        summary: String = "",
        plan: [String] = [],
        title: String = "Note vocale"
    ) {
        self.id = id
        self.createdAt = createdAt
        self.audioFileName = audioFileName
        self.transcript = transcript
        self.summary = summary
        self.plan = plan
        self.title = title
    }

    var hasPlan: Bool { !plan.isEmpty }
}

extension Note {
    static let preview = Note(
        transcript: "Idée pour l'app : ajouter un mode focus et une synthèse vocale automatique chaque soir.",
        summary: "Ajouter un mode focus + synthèse vocale quotidienne.",
        plan: ["Concevoir le mode focus", "Brancher la synthèse vocale", "Planifier l'envoi du soir"],
        title: "Idées produit"
    )
}
