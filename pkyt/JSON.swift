import Foundation

struct JSON {
    let value: Any?

    init(_ value: Any?) {
        self.value = value
    }

    init(data: Data) throws {
        value = try JSONSerialization.jsonObject(with: data)
    }

    subscript(key: String) -> JSON { JSON((value as? [String: Any])?[key]) }

    subscript(index: Int) -> JSON {
        guard let a = value as? [Any], a.indices.contains(index) else { return JSON(nil) }
        return JSON(a[index])
    }

    var array: [JSON] { (value as? [Any] ?? []).map(JSON.init) }
    var string: String? { value as? String }
    var keys: [String] { (value as? [String: Any]).map { Array($0.keys) } ?? [] }
    var exists: Bool { value != nil }

    var text: String? {
        if let s = self["simpleText"].string ?? self["content"].string { return s }
        let runs = self["runs"].array.compactMap { $0["text"].string }
        return runs.isEmpty ? nil : runs.joined()
    }

    var image: URL? {
        let list = self["thumbnails"].exists ? self["thumbnails"] : self["sources"]
        guard var s = list.array.last?["url"].string else { return nil }
        if s.hasPrefix("//") { s = "https:" + s }
        return URL(string: s)
    }
}
