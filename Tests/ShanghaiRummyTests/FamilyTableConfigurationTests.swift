import XCTest
@testable import ShanghaiRummy

final class FamilyTableConfigurationTests: XCTestCase {
    func testDefaultTableIsYouOnly() {
        let configuration = FamilyTableConfiguration()

        XCTAssertEqual(configuration.totalPlayerCount, 1)
        XCTAssertEqual(configuration.botCount, 0)
        XCTAssertEqual(configuration.invitedHumanCount, 0)
        XCTAssertEqual(configuration.actionTitle, "Start Game")
        XCTAssertFalse(
            configuration.canStart(isGameCenterAuthenticated: false)
        )
    }

    func testTableSupportsYouAndFiveBots() {
        var configuration = FamilyTableConfiguration()

        for _ in 0..<5 {
            XCTAssertTrue(configuration.addSeat(kind: .bot))
        }

        XCTAssertEqual(configuration.totalPlayerCount, 6)
        XCTAssertEqual(configuration.botCount, 5)
        XCTAssertFalse(configuration.canAddSeat)
        XCTAssertFalse(configuration.addSeat(kind: .bot))
        XCTAssertEqual(configuration.actionTitle, "Play with 5 Bots")
    }

    func testHumanSeatsRequireGameCenter() {
        var configuration = FamilyTableConfiguration()
        configuration.addSeat(kind: .human)

        XCTAssertEqual(configuration.invitedHumanCount, 1)
        XCTAssertEqual(configuration.gameCenterPlayerCount, 2)
        XCTAssertEqual(configuration.actionTitle, "Invite 1 Person")
        XCTAssertFalse(
            configuration.canStart(isGameCenterAuthenticated: false)
        )
        XCTAssertTrue(
            configuration.canStart(isGameCenterAuthenticated: true)
        )
    }

    func testRemovingLastHumanLeavesBotOnlyTable() {
        var configuration = FamilyTableConfiguration(
            seatKinds: [.bot, .bot, .bot, .human]
        )
        let humanId = configuration.seats.last!.id

        XCTAssertTrue(configuration.removeSeat(id: humanId))
        XCTAssertEqual(configuration.totalPlayerCount, 4)
        XCTAssertEqual(configuration.botCount, 3)
        XCTAssertEqual(configuration.invitedHumanCount, 0)
        XCTAssertEqual(configuration.actionTitle, "Play with 3 Bots")
    }

    func testSeatLabelsRenumberByPlayerType() {
        let configuration = FamilyTableConfiguration(
            seatKinds: [.bot, .human, .bot, .human]
        )

        XCTAssertEqual(
            configuration.seats.map { configuration.label(for: $0.id) },
            ["Bot 1", "Human 1", "Bot 2", "Human 2"]
        )
    }

    func testLastOpponentCanBeRemoved() {
        var configuration = FamilyTableConfiguration(seatKinds: [.bot])

        XCTAssertTrue(
            configuration.removeSeat(id: configuration.seats[0].id)
        )
        XCTAssertEqual(configuration.totalPlayerCount, 1)
        XCTAssertFalse(
            configuration.canStart(isGameCenterAuthenticated: true)
        )
    }
}
