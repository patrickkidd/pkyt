import XCTest
@testable import pkyt

final class LinkTests: XCTestCase {
    func testWatch() {
        XCTAssertEqual(Link("https://www.youtube.com/watch?v=jNQXAC9IVRw&t=5s"), Link(id: "jNQXAC9IVRw", start: 5))
    }

    func testHosts() {
        let urls = [
            "https://youtu.be/jNQXAC9IVRw?t=90",
            "https://m.youtube.com/watch?v=jNQXAC9IVRw&t=1m30s",
            "https://music.youtube.com/watch?v=jNQXAC9IVRw&start=90",
            "https://youtube.com/shorts/jNQXAC9IVRw?t=90s",
            "https://www.youtube.com/live/jNQXAC9IVRw?t=0h1m30s",
        ]
        for url in urls {
            XCTAssertEqual(Link(url), Link(id: "jNQXAC9IVRw", start: 90), url)
        }
    }

    func testNoTime() {
        XCTAssertNil(Link(" https://youtu.be/jNQXAC9IVRw\n")!.start)
    }

    func testSeconds() {
        XCTAssertEqual(Link.seconds("90"), 90)
        XCTAssertEqual(Link.seconds("90s"), 90)
        XCTAssertEqual(Link.seconds("1m30s"), 90)
        XCTAssertEqual(Link.seconds("1h2m3s"), 3723)
        XCTAssertNil(Link.seconds("abc"))
    }

    func testRejects() {
        XCTAssertNil(Link("https://example.com/watch?v=jNQXAC9IVRw"))
        XCTAssertNil(Link("https://www.youtube.com/watch?v=short"))
        XCTAssertNil(Link("https://www.youtube.com/channel/jNQXAC9IVRw"))
        XCTAssertNil(Link("not a url"))
    }
}
