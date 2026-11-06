import Foundation

enum FeedError: LocalizedError, Equatable {
    case status(Int)
    case shape([String])

    var errorDescription: String? {
        switch self {
        case .status(let code): "YouTube returned HTTP \(code)"
        case .shape(let keys): "YouTube changed its response format (top-level keys: \(keys.joined(separator: ", ")))"
        }
    }
}
