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

    func testCameraSafeInsetKeepsSideAndCornerSeatsVisible() {
        let targetSize = CGSize(width: 852, height: 393)
        let cameraSafeInset: CGFloat = 59
        let seatInset = cameraSafeInset + 15
        let seatHalfWidth: CGFloat = 138 / 2
        let minimumVisibleX = cameraSafeInset + 6
        let maximumVisibleX = targetSize.width - minimumVisibleX

        let fourPlayerSeats = SeatLayout.seats(
            playerCount: 4,
            youIndex: 0,
            sceneSize: targetSize,
            horizontalInset: seatInset
        )
        let left = fourPlayerSeats.first { $0.edge == .left }!
        let right = fourPlayerSeats.first { $0.edge == .right }!
        XCTAssertGreaterThanOrEqual(
            left.anchor.x - seatHalfWidth,
            minimumVisibleX
        )
        XCTAssertLessThanOrEqual(
            right.anchor.x + seatHalfWidth,
            maximumVisibleX
        )

        let sixPlayerSeats = SeatLayout.seats(
            playerCount: 6,
            youIndex: 0,
            sceneSize: targetSize,
            horizontalInset: seatInset
        )
        let topLeft = sixPlayerSeats.first { $0.edge == .topLeft }!
        let topRight = sixPlayerSeats.first { $0.edge == .topRight }!
        XCTAssertGreaterThanOrEqual(
            topLeft.anchor.x - seatHalfWidth,
            minimumVisibleX
        )
        XCTAssertLessThanOrEqual(
            topRight.anchor.x + seatHalfWidth,
            maximumVisibleX
        )
    }

    func testSixPlayerFillsAllTemplates() {
        let seats = SeatLayout.seats(playerCount: 6, youIndex: 0, sceneSize: sceneSize)
        XCTAssertEqual(seats.count, 6)
        let edges = Set(seats.map(\.edge))
        // Must include all six unique edges for the 6-player template.
        XCTAssertEqual(edges, [.bottom, .left, .topLeft, .top, .topRight, .right])
    }

    func testSixPlayerTopSeatsLeaveMeldWingsBesideCenterSeat() {
        let targetSize = CGSize(width: 852, height: 393)
        let seats = SeatLayout.seats(
            playerCount: 6,
            youIndex: 0,
            sceneSize: targetSize
        )
        let topLeft = seats.first { $0.edge == .topLeft }!
        let top = seats.first { $0.edge == .top }!
        let topRight = seats.first { $0.edge == .topRight }!
        let seatHalfWidth: CGFloat = 138 / 2

        XCTAssertEqual(
            topLeft.anchor.x,
            targetSize.width * SeatLayout.topCornerXFraction,
            accuracy: 0.001
        )
        XCTAssertGreaterThanOrEqual(
            top.anchor.x - seatHalfWidth
                - (topLeft.anchor.x + seatHalfWidth),
            172
        )
        XCTAssertGreaterThanOrEqual(
            topRight.anchor.x - seatHalfWidth
                - (top.anchor.x + seatHalfWidth),
            172
        )
    }

    func testPileCenterIsAboveMidline() {
        let center = SeatLayout.pileCenter(sceneSize: sceneSize)
        XCTAssertEqual(center.x, sceneSize.width / 2)
        XCTAssertGreaterThan(center.y, sceneSize.height / 2,
                             "piles sit above midline to leave hand room at bottom")
    }
}
