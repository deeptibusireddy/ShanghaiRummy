import XCTest
@testable import ShanghaiRummy

final class LocalBotGameSaveStoreTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var store: LocalBotGameSaveStore!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = LocalBotGameSaveStore(
            fileURL: temporaryDirectory
                .appendingPathComponent("SavedBotGame.json")
        )
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(
            atPath: temporaryDirectory.path
        ) {
            try FileManager.default.removeItem(at: temporaryDirectory)
        }
        store = nil
        temporaryDirectory = nil
    }

    func testSaveRoundTripsCompleteBotTableState() throws {
        let savedGame = makeSavedGame()

        try store.save(savedGame)

        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded, savedGame)
        XCTAssertEqual(loaded.summary.playerCount, 3)
        XCTAssertEqual(loaded.summary.botCount, 2)
        XCTAssertEqual(loaded.summary.currentHand, 1)
        XCTAssertEqual(loaded.summary.localPlayerName, "You")
        XCTAssertEqual(loaded.summary.localPlayerLevel, 1)
    }

    func testDiscardRemovesSavedGame() throws {
        try store.save(makeSavedGame())
        XCTAssertNotNil(try store.load())

        try store.discard()

        XCTAssertNil(try store.load())
    }

    func testSaveRejectsTablesWithoutBots() {
        let savedGame = makeSavedGame(cpuPlayerDifficulties: [:])

        XCTAssertThrowsError(try store.save(savedGame)) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Only local games with bots can be saved."
            )
        }
    }

    func testSaveRejectsUnsupportedFormat() {
        let savedGame = makeSavedGame(formatVersion: 99)

        XCTAssertThrowsError(try store.save(savedGame)) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "This saved game uses unsupported format 99."
            )
        }
    }

    private func makeSavedGame(
        formatVersion: Int = LocalBotGameSave.currentFormatVersion,
        cpuPlayerDifficulties: [UUID: BotDifficulty]? = nil
    ) -> LocalBotGameSave {
        let built = GameFactory.newVsCPU(
            you: "You",
            cpuNames: ["Alex", "Jordan"],
            cpuDifficulties: [.easy, .hard],
            seed: 42
        )
        let difficulties = cpuPlayerDifficulties
            ?? built.cpuDifficulties
        let localHand = built.state.players.first {
            $0.id == built.localPlayerId
        }!.hand
        return LocalBotGameSave(
            formatVersion: formatVersion,
            savedAt: Date(timeIntervalSince1970: 1_700_000_000),
            state: built.state,
            localPlayerId: built.localPlayerId,
            cpuPlayerDifficulties: difficulties,
            handOrderByPlayer: [
                built.localPlayerId: localHand.reversed().map(\.id),
            ]
        )
    }
}
