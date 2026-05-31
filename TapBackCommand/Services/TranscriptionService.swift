//
//  TranscriptionService.swift
//  TapBack Command
//
//  On-device speech-to-text using Apple's Speech framework. Uses
//  `requiresOnDeviceRecognition` when available so transcription works
//  offline and privately.
//

import Foundation
import Speech

enum TranscriptionError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:        return "Accès à la reconnaissance vocale refusé."
        case .recognizerUnavailable: return "Reconnaissance vocale indisponible pour cette langue."
        case .failed(let msg):       return msg
        }
    }
}

final class TranscriptionService {

    static let shared = TranscriptionService()
    private init() {}

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Transcribes a recorded audio file to text.
    func transcribe(url: URL, locale: Locale = Locale(identifier: "fr-FR")) async throws -> String {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw TranscriptionError.notAuthorized
        }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if !didResume { didResume = true
                        continuation.resume(throwing: TranscriptionError.failed(error.localizedDescription)) }
                    return
                }
                guard let result else { return }
                if result.isFinal, !didResume {
                    didResume = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
