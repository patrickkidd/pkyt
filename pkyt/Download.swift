import Foundation

struct Download: Codable, Identifiable, Equatable {
    let video: String
    let kind: Kind
    let title: String
    let file: String
    let duration: Double
    let date: Date

    private enum CodingKeys: String, CodingKey {
        case video = "id", kind, title, file, duration, date
    }

    init(video: String, kind: Kind, title: String, file: String, duration: Double, date: Date) {
        self.video = video
        self.kind = kind
        self.title = title
        self.file = file
        self.duration = duration
        self.date = date
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        video = try c.decode(String.self, forKey: .video)
        title = try c.decode(String.self, forKey: .title)
        file = try c.decode(String.self, forKey: .file)
        duration = try c.decode(Double.self, forKey: .duration)
        date = try c.decode(Date.self, forKey: .date)
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? Kind(file: file)
    }

    var id: String { Self.key(video, kind) }

    var thumbnail: URL { URL(string: "https://i.ytimg.com/vi/\(video)/mqdefault.jpg")! }

    static func key(_ video: String, _ kind: Kind) -> String { "\(video).\(kind.rawValue)" }
}
