import CryptoKit
import Foundation

struct InnerTube {
    static let origin = "https://www.youtube.com"
    static let version = "2.20261030.02.00"

    let cookies: [HTTPCookie]
    var session = URLSession.shared

    func page(_ endpoint: Endpoint, after token: String? = nil) async throws -> Page {
        let (data, response) = try await session.data(for: request(endpoint, after: token))
        let code = (response as! HTTPURLResponse).statusCode
        guard (200..<300).contains(code) else { throw FeedError.status(code) }
        return try Page(JSON(data: data))
    }

    func request(_ endpoint: Endpoint, after token: String?, now: Date = .now) throws -> URLRequest {
        var r = URLRequest(url: URL(string: "\(Self.origin)/youtubei/v1/\(endpoint.path)?prettyPrint=false")!)
        r.httpMethod = "POST"
        let client = ["clientName": "WEB", "clientVersion": Self.version, "hl": "en", "gl": Locale.current.region?.identifier ?? "US"]
        var body: [String: Any] = ["context": ["client": client]]
        if let token {
            body["continuation"] = token
        } else {
            body.merge(endpoint.params) { $1 }
        }
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("1", forHTTPHeaderField: "X-YouTube-Client-Name")
        r.setValue(Self.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        r.setValue(Self.origin, forHTTPHeaderField: "Origin")
        r.setValue(Self.origin, forHTTPHeaderField: "X-Origin")
        guard let sapisid = Self.sapisid(cookies) else { return r }
        r.setValue(cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; "), forHTTPHeaderField: "Cookie")
        r.setValue(Self.auth(sapisid, time: Int(now.timeIntervalSince1970)), forHTTPHeaderField: "Authorization")
        r.setValue("0", forHTTPHeaderField: "X-Goog-AuthUser")
        r.httpShouldHandleCookies = false
        return r
    }

    static func sapisid(_ cookies: [HTTPCookie]) -> String? {
        (cookies.first { $0.name == "SAPISID" } ?? cookies.first { $0.name == "__Secure-3PAPISID" })?.value
    }

    static func auth(_ sapisid: String, time: Int) -> String {
        let hash = Insecure.SHA1.hash(data: Data("\(time) \(sapisid) \(origin)".utf8))
        return "SAPISIDHASH \(time)_" + hash.map { String(format: "%02x", $0) }.joined()
    }
}
