import XCTest
@testable import pkyt

@MainActor
final class DownloadsTests: XCTestCase {
    private var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    private func item(_ id: String, _ date: Date) throws -> Download {
        let item = Download(id: id, title: "t \(id)", file: "\(id).mp4", duration: 19, date: date)
        try Data([1]).write(to: dir.appending(path: item.file))
        return item
    }

    func testDedupe() throws {
        let d = try Downloads(dir: dir)
        XCTAssertEqual(d.state("jNQXAC9IVRw"), .none)
        XCTAssertTrue(d.begin("jNQXAC9IVRw"))
        XCTAssertEqual(d.state("jNQXAC9IVRw"), .active(0))
        XCTAssertFalse(d.begin("jNQXAC9IVRw"))
        try d.add(item("jNQXAC9IVRw", .now))
        XCTAssertEqual(d.state("jNQXAC9IVRw"), .done)
        XCTAssertFalse(d.begin("jNQXAC9IVRw"))
        try d.add(item("jNQXAC9IVRw", .now))
        XCTAssertEqual(d.items.count, 1)
    }

    func testIndexPersistsNewestFirst() throws {
        let d = try Downloads(dir: dir)
        try d.add(item("aaaaaaaaaaa", Date(timeIntervalSince1970: 1)))
        try d.add(item("bbbbbbbbbbb", Date(timeIntervalSince1970: 2)))
        let reloaded = try Downloads(dir: dir)
        XCTAssertEqual(reloaded.items.map(\.id), ["bbbbbbbbbbb", "aaaaaaaaaaa"])
    }

    func testDelete() throws {
        let d = try Downloads(dir: dir)
        let a = try item("aaaaaaaaaaa", .now)
        try d.add(a)
        try d.delete(a)
        XCTAssertFalse(FileManager.default.fileExists(atPath: d.url(a).path(percentEncoded: false)))
        XCTAssertEqual(d.state(a.id), .none)
        XCTAssertEqual(try Downloads(dir: dir).items, [])
    }
}
