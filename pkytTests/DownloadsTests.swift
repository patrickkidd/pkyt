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

    private func item(_ video: String, _ kind: Kind, _ date: Date = .now) throws -> Download {
        let file = "\(video).\(kind == .audio ? "m4a" : "mp4")"
        let item = Download(video: video, kind: kind, title: "t \(video)", file: file, duration: 19, date: date)
        try Data([1]).write(to: dir.appending(path: item.file))
        return item
    }

    func testDedupePerKind() throws {
        let d = try Downloads(dir: dir)
        XCTAssertTrue(d.begin("jNQXAC9IVRw", .video))
        XCTAssertEqual(d.state("jNQXAC9IVRw", .video), .active(0))
        XCTAssertFalse(d.begin("jNQXAC9IVRw", .video))
        XCTAssertEqual(d.state("jNQXAC9IVRw", .audio), .none)
        XCTAssertTrue(d.begin("jNQXAC9IVRw", .audio))
        try d.add(item("jNQXAC9IVRw", .video))
        XCTAssertEqual(d.state("jNQXAC9IVRw", .video), .done)
        XCTAssertEqual(d.state("jNQXAC9IVRw", .audio), .active(0))
        XCTAssertFalse(d.begin("jNQXAC9IVRw", .video))
        try d.add(item("jNQXAC9IVRw", .audio))
        try d.add(item("jNQXAC9IVRw", .video))
        XCTAssertEqual(d.items.map(\.kind), [.audio, .video])
    }

    func testMigratesOldIndex() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let old = """
        [{"id":"bbbbbbbbbbb","title":"b","file":"bbbbbbbbbbb.m4a","duration":5,"date":2},
         {"id":"aaaaaaaaaaa","title":"a","file":"aaaaaaaaaaa.mp4","duration":5,"date":1}]
        """
        try Data(old.utf8).write(to: dir.appending(path: "index.json"))
        let d = try Downloads(dir: dir)
        XCTAssertEqual(d.items.map(\.video), ["bbbbbbbbbbb", "aaaaaaaaaaa"])
        XCTAssertEqual(d.items.map(\.kind), [.audio, .video])
        XCTAssertEqual(d.state("aaaaaaaaaaa", .video), .done)
        XCTAssertEqual(d.state("aaaaaaaaaaa", .audio), .none)
    }

    func testReorderPersists() throws {
        let d = try Downloads(dir: dir)
        try d.add(item("aaaaaaaaaaa", .video))
        try d.add(item("bbbbbbbbbbb", .audio))
        try d.add(item("ccccccccccc", .video))
        XCTAssertEqual(d.items.map(\.video), ["ccccccccccc", "bbbbbbbbbbb", "aaaaaaaaaaa"])
        try d.move(from: [0], to: 3)
        XCTAssertEqual(try Downloads(dir: dir).items.map(\.video), ["bbbbbbbbbbb", "aaaaaaaaaaa", "ccccccccccc"])
    }

    func testNext() throws {
        let d = try Downloads(dir: dir)
        let a = try item("aaaaaaaaaaa", .video)
        let b = try item("aaaaaaaaaaa", .audio)
        try d.add(a)
        try d.add(b)
        XCTAssertEqual(d.next(after: b), a)
        XCTAssertNil(d.next(after: a))
    }

    func testDelete() throws {
        let d = try Downloads(dir: dir)
        let a = try item("aaaaaaaaaaa", .video)
        try d.add(a)
        try d.delete(a)
        XCTAssertFalse(FileManager.default.fileExists(atPath: d.url(a).path(percentEncoded: false)))
        XCTAssertEqual(d.state(a.video, .video), .none)
        XCTAssertEqual(try Downloads(dir: dir).items, [])
    }
}
