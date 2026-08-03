import XCTest
@testable import ShanghaiRummy

/// Unit tests for the pure math in `SeatLayout`. The scene rendering itself
/// (SpriteKit nodes) isn't testable without an on-simulator run, but the
/// coordinate math is CPU-only and easy to lock down.
final class SeatLayoutTests: XCTestCase {

    let sceneSize = CGSize(width: 800, height: 400)

    func testTwoPlayerLayoutPutsYouBottomOpponentTop() {
        let seats = SeatLayout.seats(playerCount: 2, youIndex: 0, sceneSize: sceneSize)
        XCTAssertEqual(seats.count, 2)
        XCTAssertEqual(seats[0].edge, .bottom, "player 0 (=you) at bottom")
        XCTAssertEqual(seats[1].edge, .top,    "opponent at top")
    }

    func testYouRotationDoesNotChangeEdgeCount() {
        // Whichever player is "you", they end up at bottom.
        for youIndex in 0..<4 {
            let seats = SeatLayout.seats(playerCount: 4, youIndex: youIndex, sceneSize: sceneSize)
            XCTAssertEqual(seats[youIndex].edge, .bottom,
                           "player \(youIndex) as you should sit at bottom")
        }
    }

    func testFourPlayerCoversAllEdges() {
        let seats = SeatLayout.seats(playerCount: 4, youIndex: 0, sceneSize: sceneSize)
        let edges = Set(seats.map(\.edge))
        XCTAssertEqual(edges, [.bottom, .left, .top, .right])
    }

    func testSixPlayerFillsAllTemplates() {
        let seats = SeatLayout.seats(playerCount: 6, youIndex: 0, sceneSize: sceneSize)
        XCTAssertEqual(seats.count, 6)
        let edges = Set(seats.map(\.edge))
        // Must include all six unique edges for the 6-player template.
        XCTAssertEqual(edges, [.bottom, .left, .topLeft, .top, .topRight, .right])
    }

    func testPileCenterIsAboveMidline() {
        let center = SeatLayout.pileCenter(sceneSize: sceneSize)
        XCTAssertEqual(center.x, sceneSize.width / 2)
        XCTAssertGreaterThan(center.y, sceneSize.height / 2,
                             "piles sit above midline to leave hand room at bottom")
    }
}
