//
//  CaptureListView.swift
//  TapBack Command
//

import SwiftUI

struct CaptureListView: View {

    @EnvironmentObject private var captureVM: CaptureViewModel
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Palette.background.ignoresSafeArea()

                if captureVM.captures.isEmpty {
                    EmptyState(icon: "sparkles",
                               title: "Aucune capture",
                               message: "Tapote le dos de l'iPhone et choisis ⭐ pour capturer un lien, un texte ou une photo.")
                } else {
                    List {
                        ForEach(captureVM.captures) { capture in
                            CaptureRow(capture: capture)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions {
                                    if let url = capture.url {
                                        Link(destination: url) {
                                            Label("Ouvrir", systemImage: "safari")
                                        }.tint(.blue)
                                    }
                                }
                        }
                        .onDelete(perform: captureVM.delete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Captures")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { router.presentFloatingCommand() } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .tint(.white)
                }
            }
        }
    }
}

// MARK: - Shared capture row

struct CaptureRow: View {
    let capture: Capture

    var body: some View {
        HStack(spacing: 14) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(capture.title)
                    .font(.tbcSubheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if !capture.subtitle.isBlank {
                    Text(capture.subtitle)
                        .font(.tbcCaption)
                        .foregroundStyle(Constants.Palette.secondaryText)
                        .lineLimit(1)
                }
                if !capture.tags.isEmpty {
                    Text(capture.tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.tbcCaptionSmall)
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let name = capture.imageFileName, let image = StorageService.shared.image(named: name) {
            Image(uiImage: image)
                .resizable().scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Image(systemName: capture.kind.sfSymbol)
                .font(.title3)
                .frame(width: 48, height: 48)
                .background(Constants.Palette.surfaceStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Empty state (shared)

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 44)) // glyphe SF Symbol
                .foregroundStyle(.white.opacity(0.5))
            Text(title).font(.tbcSubtitleSmall.weight(.semibold)).foregroundStyle(.white)
            Text(message)
                .font(.tbcSubheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Constants.Palette.secondaryText)
                .padding(.horizontal, 40)
        }
    }
}

#Preview {
    let vm = CaptureViewModel()
    vm.add(.preview)
    return CaptureListView()
        .environmentObject(vm)
        .environmentObject(AppRouter.shared)
        .preferredColorScheme(.dark)
}
