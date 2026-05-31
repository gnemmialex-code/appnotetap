//
//  SummarizerService.swift
//  TapBack Command
//
//  Produces a short summary and (on request) a structured plan from a
//  transcript.
//
//  This ships with a fully working *local heuristic* implementation so the
//  app is functional offline and out of the box. A `RemoteSummarizer`
//  conforming to the same protocol shows exactly where to plug a real LLM
//  API (e.g. an Anthropic / on-device Foundation Models call) — swap the
//  `SummarizerService.shared.engine` to switch.
//

import Foundation
import NaturalLanguage

protocol Summarizing {
    func summarize(text: String) async throws -> String
    func generatePlan(text: String) async throws -> [String]
}

final class SummarizerService: Summarizing {

    static let shared = SummarizerService()

    /// The active engine. Defaults to the offline heuristic; assign a
    /// `RemoteSummarizer` to use a hosted model instead.
    var engine: Summarizing = LocalHeuristicSummarizer()

    private init() {}

    func summarize(text: String) async throws -> String { try await engine.summarize(text: text) }
    func generatePlan(text: String) async throws -> [String] { try await engine.generatePlan(text: text) }
}

// MARK: - Local, offline summarizer

/// Extractive summary: ranks sentences by keyword salience (lemmatised,
/// stop-word filtered) and keeps the top ones. Good enough for short voice
/// notes and requires no network or entitlement.
struct LocalHeuristicSummarizer: Summarizing {

    func summarize(text: String) async throws -> String {
        let sentences = Self.sentences(in: text)
        guard sentences.count > 1 else { return text.trimmed }

        let frequencies = Self.wordFrequencies(in: text)
        let ranked = sentences
            .map { sentence -> (String, Double) in
                let score = Self.tokens(in: sentence)
                    .reduce(0.0) { $0 + (frequencies[$1] ?? 0) }
                // Normalise by length to avoid favouring only long sentences.
                let length = max(Double(Self.tokens(in: sentence).count), 1)
                return (sentence, score / sqrt(length))
            }
            .sorted { $0.1 > $1.1 }

        let keepCount = min(2, sentences.count)
        let top = Array(ranked.prefix(keepCount)).map(\.0)
        // Preserve original ordering for readability.
        let ordered = sentences.filter { top.contains($0) }
        return ordered.joined(separator: " ").trimmed
    }

    func generatePlan(text: String) async throws -> [String] {
        // Strip the trigger phrase if present.
        var working = text
        if let range = working.range(of: Constants.Recording.planKeyword,
                                     options: [.caseInsensitive, .diacriticInsensitive]) {
            working.removeSubrange(range)
        }

        // Split into actionable steps on sentence + connector boundaries.
        let separators = CharacterSet(charactersIn: ".!?;\n")
        let rawSteps = working
            .components(separatedBy: separators)
            .flatMap { $0.components(separatedBy: " puis ") }
            .flatMap { $0.components(separatedBy: " ensuite ") }
            .map { $0.trimmed }
            .filter { !$0.isBlank && $0.count > 3 }

        let steps = rawSteps.map { step -> String in
            let cleaned = step.prefix(1).capitalized + step.dropFirst()
            return String(cleaned)
        }

        return steps.isEmpty ? ["Définir l'objectif", "Lister les étapes", "Planifier le suivi"] : steps
    }

    // MARK: - NLP helpers

    private static func sentences(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var result: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = String(text[range]).trimmed
            if !s.isBlank { result.append(s) }
            return true
        }
        return result
    }

    private static func tokens(in text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        var lemmas: [String] = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word, scheme: .lemma, options: options) { tag, range in
            let word = (tag?.rawValue ?? String(text[range])).lowercased()
            if word.count > 2, !stopWords.contains(word) { lemmas.append(word) }
            return true
        }
        return lemmas
    }

    private static func wordFrequencies(in text: String) -> [String: Double] {
        var counts: [String: Double] = [:]
        for token in tokens(in: text) { counts[token, default: 0] += 1 }
        let maxCount = counts.values.max() ?? 1
        return counts.mapValues { $0 / maxCount } // normalised 0...1
    }

    private static let stopWords: Set<String> = [
        "le","la","les","un","une","des","de","du","et","ou","à","au","aux",
        "ce","cette","ces","mon","ma","mes","ton","ta","tes","son","sa","ses",
        "que","qui","quoi","dont","où","est","être","avoir","faire","pour","avec",
        "dans","sur","par","plus","pas","ne","je","tu","il","elle","nous","vous","ils",
        "the","a","an","and","or","to","of","in","on","for","is","it","this","that"
    ]
}

// MARK: - Remote summarizer (placeholder for a real LLM API)

/// Drop-in replacement that would call a hosted model. Left intentionally
/// un-wired (throws) so no secret/key ships in source. To enable:
///   1. Add your endpoint + key (via Keychain, never hardcoded).
///   2. Implement the URLSession request/response below.
///   3. `SummarizerService.shared.engine = RemoteSummarizer()`
struct RemoteSummarizer: Summarizing {

    enum RemoteError: LocalizedError {
        case notConfigured
        var errorDescription: String? { "Le résumé distant n'est pas configuré." }
    }

    func summarize(text: String) async throws -> String {
        // Example shape — replace with a real request to your API.
        // let body = ["model": "claude-...", "prompt": "Résume: \(text)"]
        throw RemoteError.notConfigured
    }

    func generatePlan(text: String) async throws -> [String] {
        throw RemoteError.notConfigured
    }
}
