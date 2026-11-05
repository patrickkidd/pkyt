import Foundation

struct Link: Equatable {
    let id: String
    let start: Double

    private static let hosts: Set = ["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be", "www.youtu.be"]
    private static let prefixes = ["shorts", "live", "embed"]

    init?(_ text: String) {
        guard let parts = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = parts.host?.lowercased(), Self.hosts.contains(host) else { return nil }
        let query = parts.queryItems ?? []
        let path = parts.path.split(separator: "/").map(String.init)
        let id: String?
        if host.hasSuffix("youtu.be") {
            id = path.first
        } else if path.first == "watch" {
            id = query.first { $0.name == "v" }?.value
        } else if path.count >= 2, Self.prefixes.contains(path[0]) {
            id = path[1]
        } else {
            id = nil
        }
        guard let id, Self.valid(id) else { return nil }
        self.id = id
        let t = query.first { $0.name == "t" || $0.name == "start" }?.value
        start = t.flatMap(Self.seconds) ?? 0
    }

    init(id: String, start: Double) {
        self.id = id
        self.start = start
    }

    static func valid(_ id: String) -> Bool {
        id.count == 11 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }

    static func seconds(_ text: String) -> Double? {
        var total = 0
        var digits = ""
        for c in text.lowercased() {
            if c.isASCII, c.isNumber {
                digits.append(c)
                continue
            }
            guard let n = Int(digits) else { return nil }
            switch c {
            case "h": total += n * 3600
            case "m": total += n * 60
            case "s": total += n
            default: return nil
            }
            digits = ""
        }
        if !digits.isEmpty { total += Int(digits)! }
        return Double(total)
    }
}
