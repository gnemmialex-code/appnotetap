//
//  NotesListView.swift
//  TapBack Command
//

import SwiftUI
import AVKit

struct NotesListView: View {

    @EnvironmentObject private var notesVM: NotesViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Palette.background.ignoresSafeArea()

                if notesVM.notes.isEmpty {
                    EmptyState(icon: "mic.fill",
                               title: "Aucune note",
                               message: "Tapote le dos de l'iPhone et choisis 🎙️ pour enregistrer.")
                } else {
                    List {
                        ForEach(notesVM.notes) { note in
                            NavigationLink {
                                NoteDetailView(note: note)
                            } label: {
                                NoteRow(note: note)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: notesVM.delete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showOnboarding = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .tint(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { router.presentFloatingCommand() } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .tint(.white)
                }
            }
            .sheet(isPresented: $showOnboarding) {
                BackTapOnboardingView().preferredColorScheme(.dark)
            }
        }
    }
}

private struct NoteRow: View {
    let note: Note
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.title).font(.tbcHeadline).foregroundStyle(.white).lineLimit(1)
                Spacer()
                if note.hasPlan {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.tbcCaption).foregroundStyle(Constants.Palette.secondaryText)
                }
            }
            Text(note.summary.isBlank ? note.transcript : note.summary)
                .font(.tbcSubheadline)
                .foregroundStyle(Constants.Palette.secondaryText)
                .lineLimit(2)
            Text(note.createdAt.shortStamp)
                .font(.tbcCaptionSmall).foregroundStyle(.white.opacity(0.35))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .padding(.vertical, 4)
    }
}

// MARK: - Detail

struct NoteDetailView: View {
    let note: Note
    @State private var player: AVPlayer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if note.audioFileName != nil {
                    Button {
                        playAudio()
                    } label: {
                        Label("Écouter l'audio", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity).padding().glassCard()
                    }
                    .buttonStyle(.plain).foregroundStyle(.white)
                }

                block("Résumé", note.summary)
                block("Transcription", note.transcript)

                if note.hasPlan {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Plan").font(.tbcHeadline).foregroundStyle(.white)
                        ForEach(Array(note.plan.enumerated()), id: \.offset) { i, step in
                            Label(step, systemImage: "\(i + 1).circle.fill")
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .padding().frame(maxWidth: .infinity, alignment: .leading).glassCard()
                }
            }
            .padding()
        }
        .background(Constants.Palette.background.ignoresSafeArea())
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func block(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.tbcHeadline).foregroundStyle(.white)
            Text(text.isBlank ? "—" : text).font(.tbcBody).foregroundStyle(.white.opacity(0.85))
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading).glassCard()
    }

    private func playAudio() {
        guard let name = note.audioFileName else { return }
        let url = StorageService.shared.audioURL(named: name)
        player = AVPlayer(url: url)
        player?.play()
    }
}

#Preview {
    let vm = NotesViewModel()
    vm.add(.preview)
    return NotesListView()
        .environmentObject(vm)
        .environmentObject(AppRouter.shared)
        .preferredColorScheme(.dark)
}
