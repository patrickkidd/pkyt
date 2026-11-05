import AVFoundation
import XCTest
@testable import pkyt

@MainActor
final class PlayerTests: XCTestCase {
    private let a = Download(id: "aaaaaaaaaaa", title: "a", file: "clip.mp4", duration: 60, date: .now)
    private let b = Download(id: "bbbbbbbbbbb", title: "b", file: "clip.mp4", duration: 60, date: .now)
    private let clip = Bundle(for: PlayerTests.self).url(forResource: "clip", withExtension: "mp4")!

    override func setUp() {
        UserDefaults.standard.removeObject(forKey: "positions")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "positions")
    }

    private func playing(_ p: Player) async throws {
        for _ in 0..<100 where !(p.av.rate > 0 && !p.loading) {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertGreaterThan(p.av.rate, 0, p.error ?? "")
    }

    func testResumesAfterSwitchWhilePlaying() async throws {
        Positions().save(a.id, at: 30, duration: 60)
        let p = Player()
        p.play(b, at: clip)
        try await playing(p)
        p.play(a, at: clip)
        XCTAssertTrue(p.loading)
        try await playing(p)
        XCTAssertGreaterThan(p.av.currentTime().seconds, 29)
        p.stop()
        XCTAssertFalse(p.loading)
    }

    func testResumesInNewPlayer() async throws {
        let p = Player()
        p.play(a, at: clip)
        try await playing(p)
        await p.av.seek(to: CMTime(seconds: 20, preferredTimescale: 600))
        p.stop()
        let q = Player()
        q.play(a, at: clip)
        try await playing(q)
        XCTAssertGreaterThan(q.av.currentTime().seconds, 19)
        q.stop()
    }
}
