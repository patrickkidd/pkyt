import Foundation

enum Endpoint: Equatable {
    case home
    case search(String)

    var path: String {
        switch self {
        case .home: "browse"
        case .search: "search"
        }
    }

    var params: [String: String] {
        switch self {
        case .home: ["browseId": "FEwhat_to_watch"]
        case .search(let q): ["query": q]
        }
    }
}
