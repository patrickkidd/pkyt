import XCTest
@testable import pkyt

final class FeedTests: XCTestCase {
    private func page(_ name: String) throws -> Page {
        let url = Bundle(for: FeedTests.self).url(forResource: name, withExtension: "json")!
        return try Page(JSON(data: Data(contentsOf: url)))
    }

    func testSearch() throws {
        let p = try page("search")
        XCTAssertEqual(p.videos.count, 6)
        XCTAssertNotNil(p.next)
        let live = p.videos[0]
        XCTAssertEqual(live.id, "rFZHOHl-L8A")
        XCTAssertTrue(live.live)
        XCTAssertEqual(live.views, "10K watching")
        XCTAssertNil(live.published)
        let v = p.videos[1]
        XCTAssertEqual(v.id, "_jH2oTNRe7g")
        XCTAssertFalse(v.live)
        XCTAssertEqual(v.duration, "1:04:42")
        XCTAssertEqual(v.byline, "Lofi Girl · 1.7M views · 1 month ago")
        XCTAssertEqual(v.avatar?.host, "yt3.ggpht.com")
        XCTAssertEqual(v.thumbnail?.host, "i.ytimg.com")
    }

    func testSearchMore() throws {
        let p = try page("search-more")
        XCTAssertEqual(p.videos.count, 3)
        XCTAssertNotNil(p.next)
    }

    func testHome() throws {
        let p = try page("home")
        XCTAssertEqual(p.videos.map(\.id), ["rFZHOHl-L8A", "4AWXNa_ge_w", "CFGLoQIhmow", "QbJqK3uLx3c"])
        XCTAssertNotNil(p.next)
        XCTAssertTrue(p.videos[0].live)
        XCTAssertNil(p.videos[0].duration)
        let v = p.videos[1]
        XCTAssertEqual(v.duration, "1:20:16")
        XCTAssertEqual(v.byline, "Lofi Boy Music · 134 · 1mo ago")
        XCTAssertNotNil(v.avatar)
        XCTAssertNotNil(v.thumbnail)
    }

    func testChannelGrid() throws {
        let v = try page("channel").videos[0]
        XCTAssertEqual(v.duration, "1:13")
        XCTAssertNil(v.channel)
        XCTAssertEqual(v.byline, "95K views · 2 days ago")
    }

    func testSignedOutHome() throws {
        XCTAssertEqual(try page("home-signed-out"), Page(videos: [], next: nil))
    }

    func testUnknownShape() {
        XCTAssertThrowsError(try Page(JSON(["error": ["code": 400]]))) {
            XCTAssertEqual($0 as? FeedError, .shape(["error"]))
        }
    }

    func testAuth() {
        XCTAssertEqual(InnerTube.auth("abc/def", time: 1_700_000_000), "SAPISIDHASH 1700000000_747622f274182ecf105054645d6a0093199ab03d")
    }

    func testRequest() throws {
        let anon = try InnerTube(cookies: []).request(.search("lofi"), after: nil)
        XCTAssertNil(anon.value(forHTTPHeaderField: "Authorization"))
        let body = try JSON(data: anon.httpBody!)
        XCTAssertEqual(body["query"].string, "lofi")
        XCTAssertEqual(body["context"]["client"]["clientName"].string, "WEB")

        let cookie = HTTPCookie(properties: [.name: "SAPISID", .value: "abc/def", .domain: ".youtube.com", .path: "/"])!
        let r = try InnerTube(cookies: [cookie]).request(.home, after: "tok", now: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(r.url?.absoluteString, "https://www.youtube.com/youtubei/v1/browse?prettyPrint=false")
        XCTAssertEqual(r.value(forHTTPHeaderField: "Authorization"), "SAPISIDHASH 1700000000_747622f274182ecf105054645d6a0093199ab03d")
        XCTAssertEqual(r.value(forHTTPHeaderField: "Cookie"), "SAPISID=abc/def")
        XCTAssertEqual(r.value(forHTTPHeaderField: "X-Goog-AuthUser"), "0")
        let b = try JSON(data: r.httpBody!)
        XCTAssertEqual(b["continuation"].string, "tok")
        XCTAssertNil(b["browseId"].string)
    }
}
