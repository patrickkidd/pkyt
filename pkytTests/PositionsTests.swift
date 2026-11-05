import XCTest
@testable import pkyt

final class PositionsTests: XCTestCase {
    private func positions() -> Positions {
        Positions(UserDefaults(suiteName: UUID().uuidString)!)
    }

    func testLinkWins() {
        let p = positions()
        p.save("jNQXAC9IVRw", at: 120, duration: 600)
        XCTAssertEqual(p.start("jNQXAC9IVRw", link: 30), 30)
        XCTAssertEqual(p.start("jNQXAC9IVRw", link: 0), 0)
    }

    func testSavedUsed() {
        let p = positions()
        XCTAssertEqual(p.start("jNQXAC9IVRw", link: nil), 0)
        p.save("jNQXAC9IVRw", at: 120, duration: 600)
        XCTAssertEqual(p.start("jNQXAC9IVRw", link: nil), 120)
        p.save("jNQXAC9IVRw", at: 3, duration: 600)
        XCTAssertEqual(p.start("jNQXAC9IVRw", link: nil), 120)
    }

    func testClearedNearEnd() {
        let p = positions()
        p.save("jNQXAC9IVRw", at: 120, duration: 600)
        p.save("jNQXAC9IVRw", at: 595, duration: 600)
        XCTAssertEqual(p.start("jNQXAC9IVRw", link: nil), 0)
        XCTAssertTrue(p.all.isEmpty)
    }
}
