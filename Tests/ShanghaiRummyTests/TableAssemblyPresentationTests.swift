import XCTest
@testable import ShanghaiRummy

final class TableAssemblyPresentationTests: XCTestCase {
    func testChoosingGuestsKeepsConfiguredBotsVisible() throws {
        var configuration = FamilyTableConfiguration(
            seatKinds: [.human, .bot, .bot]
        )
        let firstBot = try XCTUnwrap(
            configuration.seats.first { $0.kind == .bot }
        )
        configuration.setBotDifficulty(.medium, for: firstBot.id)

        let presentation = TableAssemblyPresentation(
            configuration: configuration,
            connectedGuestNames: [],
            isMatchActive: false,
            statusMessage: ""
        )

        XCTAssertEqual(presentation.stage, .choosingGuests)
        XCTAssertEqual(
            presentation.configuredSeats.map(\.title),
            ["Guest 1", "Bot 1", "Bot 2"]
        )
        XCTAssertEqual(
            presentation.configuredSeats.map(\.subtitle),
            [
                "Choose in Game Center",
                "House player - Medium",
                "House player - Hard",
            ]
        )
        XCTAssertEqual(
            presentation.configuredSeats.map(\.status),
            [.choose, .ready, .ready]
        )
        XCTAssertEqual(
            presentation.chooseGuestsTitle,
            "Choose 1 Guest in Game Center"
        )
    }

    func testGatheringMapsConnectedNamesWithoutRemovingBots() {
        let configuration = FamilyTableConfiguration(
            seatKinds: [.human, .bot, .human]
        )

        let presentation = TableAssemblyPresentation(
            configuration: configuration,
            connectedGuestNames: ["Morgan"],
            isMatchActive: true,
            statusMessage: "Waiting for one more player..."
        )

        XCTAssertEqual(presentation.stage, .gathering)
        XCTAssertEqual(presentation.connectedGuestCount, 1)
        XCTAssertEqual(presentation.remainingGuestCount, 1)
        XCTAssertEqual(
            presentation.configuredSeats.map(\.title),
            ["Morgan", "Bot 1", "Guest 2"]
        )
        XCTAssertEqual(
            presentation.configuredSeats.map(\.status),
            [.ready, .ready, .joining]
        )
        XCTAssertEqual(
            presentation.progressDetail,
            "Waiting for one more player..."
        )
    }

    func testReadyStageLeadsIntoOpeningDraw() {
        let configuration = FamilyTableConfiguration(
            seatKinds: [.bot, .human, .bot]
        )

        let presentation = TableAssemblyPresentation(
            configuration: configuration,
            connectedGuestNames: ["Morgan"],
            isMatchActive: true,
            statusMessage: ""
        )

        XCTAssertEqual(presentation.stage, .ready)
        XCTAssertEqual(presentation.progressTitle, "Everyone is ready")
        XCTAssertEqual(
            presentation.progressDetail,
            "Drawing cards for seating order..."
        )
    }
}
