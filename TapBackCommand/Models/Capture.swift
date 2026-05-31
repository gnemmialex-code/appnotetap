//
//  Capture.swift
//  TapBack Command
//
//  A "smart capture" of the user's current context: a link from Safari /
//  YouTube, selected text from Messages, or an image from Photos with
//  auto-generated tags.
//

import Foundation

struct Capture: Identifiable, Codable, Equatable {
    let id: UUID
    var createdAt: Date
    var kind: Kind
    var title: String
    var subtitle: String
    /// URL string for links; nil for plain text / image captures.
    var urlString: String?
    /// Filename of an associated image inside Documents/Images.
    var imageFileName: String?
    var tags: [String]

    enum Kind: String, Codable, CaseIterable {
        case safari
        case youtube
        case messages
        case photo
        case generic

        var sfSymbol: String {
            switch self {
            case .safari:   return "safari"
            case .youtube:  return "play.rectangle.fill"
            case .messages: return "text.bubble.fill"
            case .photo:    return "photo.fill"
            case .generic:  return "sparkles"
            }
        }

        var label: String {
            switch self {
            case .safari:   return "Safari"
            case .youtube:  return "YouTube"
            case .messages: return "Messages"
            case .photo:    return "Photo"
            case .generic:  return "Capture"
            }
        }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        kind: Kind,
        title: String,
        subtitle: String = "",
        urlString: String? = nil,
        imageFileName: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.urlString = urlString
        self.imageFileName = imageFileName
        self.tags = tags
    }

    var url: URL? { urlString.flatMap(URL.init(string:)) }
}

extension Capture {
    static let preview = Capture(
        kind: .youtube,
        title: "SwiftUI Animations — Deep Dive",
        subtitle: "youtube.com • 12:34",
        urlString: "https://youtube.com/watch?v=abc123&t=754",
        tags: ["swiftui", "animation", "ios"]
    )
}
