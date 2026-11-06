import Foundation

enum Kind: String, Codable, CaseIterable {
    case audio
    case video

    init(file: String) {
        self = file.hasSuffix(".m4a") ? .audio : .video
    }

    var label: String {
        switch self {
        case .audio: "Audio"
        case .video: "Video"
        }
    }

    var symbol: String {
        switch self {
        case .audio: "headphones"
        case .video: "film"
        }
    }
}
