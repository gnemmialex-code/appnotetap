//
//  CaptureView.swift
//  TapBack Command
//
//  Smart capture entry point. Offers:
//   • "Capturer le contexte" → reads the clipboard (Safari/YouTube link,
//     Messages text) and classifies it.
//   • Photo picker → on-device Vision tagging.
//   • A manual URL/text field as a fallback.
//
//  See ContextDetectionService for why cross-app reading uses clipboard /
//  share sheet rather than directly inspecting the foreground app.
//

import SwiftUI
import PhotosUI

struct CaptureView: View {

    @EnvironmentObject private var vm: CaptureViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var manualText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Palette.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    captureContextButton
                    photoButton
                    manualField

                    if let capture = vm.lastCapture {
                        CaptureRow(capture: capture)
                            .glassCard()
                            .transition(.scale.combined(with: .opacity))
                    }

                    if let message = vm.statusMessage {
                        Text(message)
                            .font(.tbcCaption)
                            .foregroundStyle(Constants.Palette.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Capture intelligente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }.foregroundStyle(.white)
                }
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    vm.capture(image: image)
                }
            }
        }
    }

    private var captureContextButton: some View {
        Button {
            withAnimation { vm.captureFromContext() }
        } label: {
            actionLabel(icon: "sparkles", title: "Capturer le contexte",
                        subtitle: "Lien ou texte copié")
        }
        .buttonStyle(.plain)
    }

    private var photoButton: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            actionLabel(icon: "photo.on.rectangle.angled", title: "Capturer une photo",
                        subtitle: "Tags IA automatiques")
        }
    }

    private var manualField: some View {
        HStack(spacing: 10) {
            TextField("Coller une URL ou un texte…", text: $manualText)
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button {
                addManual()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(manualText.isBlank ? .white.opacity(0.3) : .white)
            }
            .disabled(manualText.isBlank)
        }
        .padding()
        .glassCard()
    }

    private func addManual() {
        guard !manualText.isBlank else { return }
        if let url = URL(string: manualText.trimmed), url.scheme != nil {
            vm.add(ContextDetectionService.shared.classify(url: url))
        } else {
            vm.capture(sharedText: manualText)
        }
        manualText = ""
        hideKeyboard()
    }

    private func actionLabel(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Constants.Palette.surfaceStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.tbcHeadline)
                Text(subtitle).font(.tbcCaption).foregroundStyle(Constants.Palette.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Constants.Palette.secondaryText)
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity)
        .glassCard()
    }
}

#Preview {
    CaptureView()
        .environmentObject(CaptureViewModel())
        .preferredColorScheme(.dark)
}
