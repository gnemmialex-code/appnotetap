//
//  VoiceRecorderView.swift
//  TapBack Command
//
//  Record button + animated waveform + timer, then transcript / summary /
//  plan once processing finishes.
//

import SwiftUI

struct VoiceRecorderView: View {

    /// Called when a note is finalised and should be saved.
    let onSave: (Note) -> Void

    @StateObject private var vm = RecorderViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Palette.background.ignoresSafeArea()

                VStack(spacing: 28) {
                    header
                    Spacer(minLength: 0)

                    switch vm.phase {
                    case .idle, .recording:
                        recordingArea
                    case .processing:
                        processingArea
                    case .done:
                        resultsArea
                    case .error(let message):
                        errorArea(message)
                    }

                    Spacer(minLength: 0)
                    controls
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .task {
            await vm.prepare()
            vm.onSaved = { note in onSave(note) }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 6) {
            Text("Note vocale")
                .font(.tbcSubtitle)
                .foregroundStyle(.white)
            Text(statusText)
                .font(.tbcSubheadline)
                .foregroundStyle(Constants.Palette.secondaryText)
        }
    }

    private var statusText: String {
        switch vm.phase {
        case .idle:       return "Appuie pour enregistrer (max 30 s)"
        case .recording:  return vm.elapsed.clockString
        case .processing: return "Transcription en cours…"
        case .done:       return "Terminé"
        case .error:      return "Erreur"
        }
    }

    private var recordingArea: some View {
        VStack(spacing: 32) {
            WaveformView(level: vm.level, isActive: vm.isRecording)
                .frame(height: 90)

            RecordButton(isRecording: vm.isRecording) {
                vm.toggleRecording()
            }
        }
    }

    private var processingArea: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text("Transcription & résumé…")
                .foregroundStyle(Constants.Palette.secondaryText)
        }
    }

    private var resultsArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                resultBlock(title: "Résumé", icon: "text.append", text: vm.summary)
                resultBlock(title: "Transcription", icon: "quote.bubble", text: vm.transcript)

                if vm.hasPlan {
                    planBlock
                } else {
                    Button {
                        vm.makePlan()
                    } label: {
                        Label("Générer un plan", systemImage: "list.bullet.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .glassCard()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private var planBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Plan", systemImage: "list.bullet.rectangle.fill")
                .font(.tbcHeadline)
                .foregroundStyle(.white)
            ForEach(Array(vm.plan.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(.footnote, design: .default, weight: .bold)) // numéro dans la pastille
                        .frame(width: 22, height: 22)
                        .background(Constants.Palette.surfaceStrong, in: Circle())
                        .foregroundStyle(.white)
                    Text(step)
                        .font(.tbcBody)
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func resultBlock(title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.tbcHeadline)
                .foregroundStyle(.white)
            Text(text.isBlank ? "—" : text)
                .font(.tbcBody)
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .glassCard()
    }

    private func errorArea(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.tbcLargeTitle)
                .foregroundStyle(.yellow)
            Text(message)
                .font(.tbcSubheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Constants.Palette.secondaryText)
        }
    }

    private var controls: some View {
        Group {
            switch vm.phase {
            case .done, .error:
                HStack(spacing: 12) {
                    Button {
                        vm.reset()
                    } label: {
                        Label("Nouvelle", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity).padding().glassCard()
                    }
                    Button {
                        dismiss()
                    } label: {
                        Label("Sauver & fermer", systemImage: "checkmark")
                            .frame(maxWidth: .infinity).padding()
                            .background(.white, in: RoundedRectangle(cornerRadius: Constants.Layout.buttonCorner, style: .continuous))
                            .foregroundStyle(.black)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Record button

private struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 4)
                    .frame(width: 92, height: 92)
                RoundedRectangle(cornerRadius: isRecording ? 8 : 40, style: .continuous)
                    .fill(Constants.Palette.record)
                    .frame(width: isRecording ? 38 : 76,
                           height: isRecording ? 38 : 76)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "Arrêter l'enregistrement" : "Démarrer l'enregistrement")
    }
}

// MARK: - Waveform

struct WaveformView: View {
    let level: CGFloat
    let isActive: Bool

    private let barCount = 30
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width / CGFloat(barCount)
            HStack(alignment: .center, spacing: width * 0.4) {
                ForEach(0..<barCount, id: \.self) { i in
                    Capsule()
                        .fill(Color.white.opacity(isActive ? 0.9 : 0.25))
                        .frame(width: width * 0.6,
                               height: barHeight(for: i, maxHeight: geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { animate() }
    }

    private func barHeight(for index: Int, maxHeight: CGFloat) -> CGFloat {
        guard isActive else { return maxHeight * 0.12 }
        // Combine live level with a travelling sine for an organic look.
        let wave = sin(phase + CGFloat(index) * 0.5)
        let normalized = (wave + 1) / 2                 // 0...1
        let mixed = (0.35 + 0.65 * level) * normalized  // scale by mic level
        return max(maxHeight * 0.12, maxHeight * mixed)
    }

    private func animate() {
        withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: false)) {
            phase = .pi * 2
        }
    }
}

#Preview {
    VoiceRecorderView { _ in }
        .preferredColorScheme(.dark)
}
