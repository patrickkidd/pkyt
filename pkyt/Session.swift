import Foundation
import Observation
import WebKit

@MainActor
@Observable
final class Session {
    static let shared = Session()
    static let domains = ["youtube.com", "google.com"]

    private(set) var signedIn = false
    @ObservationIgnored let store = WKWebsiteDataStore.default()

    func cookies() async -> [HTTPCookie] {
        await store.httpCookieStore.allCookies().filter { $0.domain.hasSuffix("youtube.com") }
    }

    func client() async -> InnerTube {
        InnerTube(cookies: await cookies())
    }

    func refresh() async {
        signedIn = InnerTube.sapisid(await cookies()) != nil
    }

    func signOut() async {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await store.dataRecords(ofTypes: types)
            .filter { r in Self.domains.contains { r.displayName.hasSuffix($0) } }
        await store.removeData(ofTypes: types, for: records)
        await refresh()
    }
}
