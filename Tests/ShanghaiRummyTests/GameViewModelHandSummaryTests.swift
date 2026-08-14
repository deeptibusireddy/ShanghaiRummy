import XCTest
@testable import ShanghaiRummy

/// Covers M2e: end-of-hand and end-of-game scoreboard summaries exposed
/// by GameViewModel for the round-over / game-over overlays.
@MainActor
final class GameViewModelHandSummaryTests: XCTestCase {

    private func c(_ suit: Suit, _ rank: Rank) -> Card { Card(suit: suit, rank: rank) }

    private func vm(state: GameState) -> GameViewModel {
        GameViewModel(state: state)
    }

    // MARK: - pendingHandSummary

    func testPendingHandSummaryIsNilWhenNotRoundEnded() {
        let s = GameFactory.newGame(playerNames: ["A", "B"], seed: 1)
        XCTAssertNil(vm(state: s).pendingHandSummary)
    }

    func testDemoHandOverSummaryScoresWentOutAtZero() throws {
        let v = vm(state: GameFactory.demoHandOver())
        let rows = try XCTUnwrap(v.pendingHandSummary)
        XCTAssertEqual(rows.count, 4)
        // Sam went out this round.
        let sam = try XCTUnwrap(rows.first(where: { $0.name == "Sam" }))
        XCTAssertTrue(sam.wentOut)
        XCTAssertEqual(sam.roundPoints, 0)
        XCTAssertEqual(sam.totalAfter, sam.roundPoints + 10)
    }

    func testDemoHandOverPenaltiesMatchCardPoints() throws {
        let v = vm(state: GameFactory.demoHandOver())
        let rows = try XCTUnwrap(v.pendingHandSummary)
        // You: K(10) + Q(10) + 4(5) = 25
        let you = try XCTUnwrap(rows.first(where: { $0.name == "You" }))
        XCTAssertEqual(you.roundPoints, 25)
        XCTAssertEqual(you.totalAfter, 40 + 25)
        // Alex: A(15) + A(15) + 9(5) = 35
        let alex = try XCTUnwrap(rows.first(where: { $0.name == "Alex" }))
        XCTAssertEqual(alex.roundPoints, 35)
        XCTAssertEqual(alex.totalAfter, 85 + 35)
        // Jordan (didn't go down): K(10) + J(10) + T(10) + joker(20) = 50
        let jordan = try XCTUnwrap(rows.first(where: { $0.name == "Jordan" }))
        XCTAssertEqual(jordan.roundPoints, 50)
        XCTAssertFalse(jordan.didLevelUp)
    }

    func testHandSummaryIsSortedByTotalAscending() throws {
        let v = vm(state: GameFactory.demoHandOver())
        let rows = try XCTUnwrap(v.pendingHandSummary)
        let totals = rows.map(\.totalAfter)
        XCTAssertEqual(totals, totals.sorted())
    }

    func testDidLevelUpTracksHasGoneDownFlag() throws {
        let v = vm(state: GameFactory.demoHandOver())
        let rows = try XCTUnwrap(v.pendingHandSummary)
        let jordan = try XCTUnwrap(rows.first(where: { $0.name == "Jordan" }))
        XCTAssertFalse(jordan.didLevelUp)
        let you = try XCTUnwrap(rows.first(where: { $0.name == "You" }))
        XCTAssertTrue(you.didLevelUp)
    }

    // MARK: - advanceHand transitions

    func testAdvanceHandFromRoundEndedLevelsUpWinners() {
        let v = vm(state: GameFactory.demoHandOver())
        let jordanLevelBefore = v.state.players.first { $0.name == "Jordan" }!.currentLevel
        let youLevelBefore = v.state.players.first { $0.name == "You" }!.currentLevel
        v.advanceHand()
        // Fresh hand dealt: phase back to awaitingDraw.
        XCTAssertEqual(v.state.phase, .awaitingDraw)
        let jordanAfter = v.state.players.first { $0.name == "Jordan" }!.currentLevel
        let youAfter = v.state.players.first { $0.name == "You" }!.currentLevel
        XCTAssertEqual(jordanAfter, jordanLevelBefore, "Jordan didn't go down — no level up")
        XCTAssertEqual(youAfter, youLevelBefore + 1, "You went down — level should advance")
    }

    // MARK: - liveScoreboard

    func testLiveScoreboardShowsLevelAndCumulativeScoreLowestFirst() {
        let v = vm(state: GameFactory.demoMidGame())

        XCTAssertEqual(
            v.liveScoreboard.map(\.name),
            ["Jordan", "You", "Alex", "Sam"]
        )
        XCTAssertEqual(v.liveScoreboard.map(\.currentLevel), [3, 2, 2, 2])
        XCTAssertEqual(v.liveScoreboard.map(\.totalScore), [30, 45, 120, 180])
    }

    func testScorecardPresentationIsUIOnlyAndClosesWhenHandEnds() {
        let v = vm(state: GameFactory.demoMidGame())
        let originalState = v.state

        v.presentScorecard()
        XCTAssertTrue(v.isScorecardPresented)
        XCTAssertEqual(v.state, originalState)

        v.dismissScorecard()
        XCTAssertFalse(v.isScorecardPresented)

        v.presentScorecard()
        v.receiveAuthoritativeState(GameFactory.demoHandOver())
        XCTAssertFalse(v.isScorecardPresented)

        v.presentScorecard()
        XCTAssertFalse(v.isScorecardPresented)
    }

    // MARK: - finalScoreboard

    func testFinalScoreboardNilWhileGameLive() {
        let s = GameFactory.newGame(playerNames: ["A", "B"], seed: 1)
        XCTAssertNil(vm(state: s).finalScoreboard)
    }

    func testDemoGameOverScoreboard() throws {
        let v = vm(state: GameFactory.demoGameOver())
        let rows = try XCTUnwrap(v.finalScoreboard)
        XCTAssertEqual(rows.count, 4)
        // Sorted ascending — You (245) should be first.
        XCTAssertEqual(rows.first?.name, "You")
        XCTAssertTrue(rows.first?.isWinner ?? false)
        XCTAssertFalse(rows.last?.isWinner ?? true)
    }
}
