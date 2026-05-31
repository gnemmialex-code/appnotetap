//
//  ContextDetectionService.swift
//  TapBack Command
//
//  Builds a `Capture` from whatever context is currently available.
//
//  IMPORTANT iOS sandbox note:
//  A third-party app CANNOT read the foreground app's content (Safari URL,
//  Messages selection, etc.) directly. The supported, App-Store-safe routes
//  are:
//    • Share Sheet / Share Extension — the user taps "Partager → TapBack"
//      in Safari/YouTube/Messages/Photos. The extension hands us the URL,
//      text or image. (This is the primary mechanism.)
//    • UIPasteboard — if the user copied a link/text, we can read it (iOS
//      shows a paste banner). Used here as the in-app fallback for the
//      Capture button.
//    • PHPicker — user picks a photo; we then run on-device Vision tagging.
//
//  The methods below implement the pasteboard fallback + photo tagging that
//  work entirely within the app, and document where shared-extension data
//  would arrive.
//

import Foundation
import UIKit
import Vision
import UniformTypeIdentifiers

final class ContextDetectionService {

    static let shared = ContextDetectionService()
    private init() {}

    /// Best-effort capture from the clipboard. Detects URLs (and classifies
    /// YouTube vs generic web) or falls back to plain text.
    func detectFromPasteboard() -> Capture? {
        let pb = UIPasteboard.general

        if pb.hasURLs, let url = pb.url ?? pb.urls?.first {
            return classify(url: url)
        }
        if pb.hasStrings, let text = pb.string, !text.isBlank {
            // The string itself might be a URL.
            if let url = URL(string: text.trimmed), url.scheme != nil {
                return classify(url: url)
            }
            return Capture(kind: .messages,
                           title: String(text.trimmed.prefix(80)),
                           subtitle: "Texte copié",
                           tags: keywords(from: text))
        }
        return nil
    }

    /// Classifies a URL into a Safari or YouTube capture, extracting the
    /// YouTube timestamp (`t=` / `start=`) when present.
    func classify(url: URL) -> Capture {
        let host = url.host?.lowercased() ?? ""
        if host.contains("youtube.com") || host.contains("youtu.be") {
            let seconds = youTubeTimestamp(from: url)
            let stamp = seconds.map { " • " + TimeInterval($0).clockString } ?? ""
            return Capture(kind: .youtube,
                           title: url.absoluteString,
                           subtitle: "youtube\(stamp)",
                           urlString: url.absoluteString,
                           tags: ["video"])
        }
        return Capture(kind: .safari,
                       title: url.absoluteString,
                       subtitle: host,
                       urlString: url.absoluteString,
                       tags: [])
    }

    /// Entry point used by a Share Extension hand-off (text/URL/image arrive
    /// pre-parsed from the system share sheet).
    func capture(fromSharedURL url: URL) -> Capture { classify(url: url) }

    func capture(fromSharedText text: String) -> Capture {
        Capture(kind: .messages,
                title: String(text.trimmed.prefix(80)),
                subtitle: "Partagé",
                tags: keywords(from: text))
    }

    /// Saves the image and tags it on-device with Vision.
    func capture(fromImage image: UIImage) async -> Capture {
        let fileName = StorageService.shared.saveImage(image)
        let tags = await imageTags(image)
        return Capture(kind: .photo,
                       title: "Photo capturée",
                       subtitle: tags.prefix(3).joined(separator: ", "),
                       imageFileName: fileName,
                       tags: tags)
    }

    // MARK: - Helpers

    private func youTubeTimestamp(from url: URL) -> Int? {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        for key in ["t", "start"] {
            if let value = items.first(where: { $0.name == key })?.value {
                // Supports "754" or "12m34s" style.
                if let secs = Int(value) { return secs }
                return parseHms(value)
            }
        }
        return nil
    }

    private func parseHms(_ s: String) -> Int? {
        var total = 0, current = 0, found = false
        for ch in s {
            if let d = ch.wholeNumberValue { current = current * 10 + d; found = true }
            else {
                let mult = (ch == "h") ? 3600 : (ch == "m") ? 60 : 1
                total += current * mult; current = 0
            }
        }
        return found ? total + current : nil
    }

    private func keywords(from text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 4 }
            .prefix(3)
            .map(String.init)
    }

    /// On-device image classification → top tags.
    private func imageTags(_ image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, _ in
                let tags = (request.results as? [VNClassificationObservation] ?? [])
                    .filter { $0.confidence > 0.5 }
                    .prefix(5)
                    .map { $0.identifier }
                continuation.resume(returning: Array(tags))
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }
}
