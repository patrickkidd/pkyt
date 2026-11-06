import AVFoundation
import XCTest
@testable import pkyt

@MainActor
final class PlayerTests: XCTestCase {
    private let clip = Bundle(for: PlayerTests.self).url(forResource: "clip", withExtension: "mp4")!
    private var dir: URL!
    private var downloads: Downloads!
    private var a: Download!
    private var b: Download!

    override func setUpWithError() throws {
        UserDefaults.standard.removeObject(forKey: "positions")
        dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        downloads = try Downloads(dir: dir)
        b = try add("bbbbbbbbbbb")
        a = try add("aaaaaaaaaaa")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "positions")
        try? FileManager.default.removeItem(at: dir)
    }

    private func add(_ video: String) throws -> Download {
        let item = Download(video: video, kind: .video, title: video, file: "\(video).mp4", duration: 60, date: .now)
        try FileManager.default.copyItem(at: clip, to: downloads.url(item))
        try downloads.add(item)
        return item
    }

    private func playing(_ p: Player) async throws {
        for _ in 0..<100 where !(p.av.rate > 0 && !p.loading) {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertGreaterThan(p.av.rate, 0, p.error ?? "")
    }

    func testResumesAfterSwitchWhilePlaying() async throws {
        Positions().save(a.video, at: 30, duration: 60)
        let p = Player(downloads: downloads)
        p.play(b)
        try await playing(p)
        p.play(a)
        XCTAssertTrue(p.loading)
        try await playing(p)
        XCTAssertGreaterThan(p.av.currentTime().seconds, 29)
        p.stop()
        XCTAssertFalse(p.loading)
    }

    func testResumesInNewPlayer() async throws {
        let p = Player(downloads: downloads)
        p.play(a)
        try await playing(p)
        await p.av.seek(to: CMTime(seconds: 20, preferredTimescale: 600))
        p.stop()
        let q = Player(downloads: downloads)
        q.play(a)
        try await playing(q)
        XCTAssertGreaterThan(q.av.currentTime().seconds, 19)
        q.stop()
    }

    func testAdvancesToNext() async throws {
        let p = Player(downloads: downloads)
        p.play(a)
        try await playing(p)
        await p.av.seek(to: CMTime(seconds: 58, preferredTimescale: 600))
        for _ in 0..<100 where p.item?.id != b.id {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(p.item?.id, b.id)
        try await playing(p)
        XCTAssertNil(Positions().all[a.video])
        p.stop()
    }
}
