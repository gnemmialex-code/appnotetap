//
//  RecorderViewModel.swift
//  TapBack Command
//
//  Orchestrates the full voice-note pipeline:
//  record → stop → transcribe → summarize → (optional) plan → save.
//

import Foundation
import SwiftUI

@MainActor
final class RecorderViewModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case recording
        case processing       // transcribing + summarizing
        case done
        case error(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var transcript: String = ""
    @Published private(set) var summary: String = ""
    @Published private(set) var plan: [String] = []

    // Live UI values forwarded from the recorder service.
    @Published private(set) var level: CGFloat = 0
    @Published private(set) var elapsed: TimeInterval = 0

    private let recorder = AudioRecorderService()
    private let transcription = TranscriptionService.shared
    private let summarizer = SummarizerService.shared

    private var levelObservation: Task<Void, Never>?
    private var currentAudioFile: String?

    /// Called by the view; injected so the note can be persisted.
    var onSaved: ((Note) -> Void)?

    var isRecording: Bool { phase == .recording }
    var hasPlan: Bool { !plan.isEmpty }

    // MARK: - Permissions

    func prepare() async {
        _ = await recorder.requestPermission()
        _ = await transcription.requestPermission()
    }

    // MARK: - Recording lifecycle

    func toggleRecording() {
        switch phase {
        case .recording: stop()
        default: start()
        }
    }

    func start() {
        reset()
        guard let fileName = recorder.startRecording() else {
            phase = .error("Impossible de démarrer l'enregistrement.")
            return
        }
        currentAudioFile = fileName
        phase = .recording
        Haptics.shared.impact(.medium)
        observeRecorder()
    }

    func stop() {
        let fileName = recorder.stopRecording()
        currentAudioFile = fileName
        levelObservation?.cancel()
        level = 0
        Haptics.shared.impact(.rigid)
        Task { await process() }
    }

    // MARK: - Processing pipeline

    private func process() async {
        guard let fileName = currentAudioFile else {
            phase = .error("Aucun fichier audio.")
            return
        }
        phase = .processing
        let url = StorageService.shared.audioURL(named: fileName)

        do {
            let text = try await transcription.transcribe(url: url)
            transcript = text.isBlank ? "(Aucune parole détectée)" : text

            summary = (try? await summarizer.summarize(text: transcript)) ?? ""

            // Auto-generate a plan if the user explicitly asked for one.
            if transcript.range(of: Constants.Recording.planKeyword,
                                 options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                plan = (try? await summarizer.generatePlan(text: transcript)) ?? []
            }

            phase = .done
            Haptics.shared.notify(.success)
            persist()
        } catch {
            phase = .error(error.localizedDescription)
            Haptics.shared.notify(.error)
        }
    }

    /// Manually request a plan after the fact (button in the UI).
    func makePlan() {
        Task {
            plan = (try? await summarizer.generatePlan(text: transcript)) ?? []
            persist()
        }
    }

    private func persist() {
        let note = Note(
            audioFileName: currentAudioFile,
            transcript: transcript,
            summary: summary,
            plan: plan,
            title: summary.isBlank ? "Note vocale" : String(summary.prefix(40))
        )
        onSaved?(note)
    }

    // MARK: - Helpers

    func reset() {
        transcript = ""; summary = ""; plan = []
        elapsed = 0; level = 0
        phase = .idle
    }

    private func observeRecorder() {
        levelObservation = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.recorder.isRecording {
                self.level = self.recorder.level
                self.elapsed = self.recorder.elapsed
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
            }
            // If the recorder auto-stopped at max duration, sync state.
            if !self.recorder.isRecording, self.phase == .recording {
                self.stop()
            }
        }
    }
}
