import Foundation
import XCTest
@testable import ShanghaiRummy

final class GameSimulationTests: XCTestCase {
    private static let gamesPerBatch = 50

    private struct ActionTotals: Codable {
        var stockChoices = 0
        var discardTakes = 0
        var contractsLaid = 0
        var cardsLaidOff = 0
        var wildRedemptions = 0
        var discards = 0
        var outOfTurnBuys = 0
        var outOfTurnPasses = 0
        var handsAdvanced = 0

        mutating func record(
            _ action: TurnEngine.Action,
            in state: GameState
        ) {
            switch action {
            case .draw(_, let source):
                if source == .stock {
                    stockChoices += 1
                } else {
                    discardTakes += 1
                }
            case .goDown:
                contractsLaid += 1
            case .addToMeld:
                cardsLaidOff += 1
            case .redeemWild:
                wildRedemptions += 1
            case .discard:
                discards += 1
            case .acceptBuyOffer(let playerId):
                if playerId != state.currentPlayerId {
                    outOfTurnBuys += 1
                }
            case .passBuyOffer(let playerId):
                if playerId != state.currentPlayerId {
                    outOfTurnPasses += 1
                }
            case .advanceHand:
                handsAdvanced += 1
            }
        }
    }

    private struct GameRecord: Codable {
        let playerCount: Int
        let gameNumber: Int
        let seed: UInt64
        let actionCount: Int
        let turnCount: Int
        let hands: Int
        let wentOutHands: Int
        let stockExhaustedHands: Int
        let stockReshuffles: Int
        let maximumHandSize: Int
        let winnerSeats: [Int]
        let finalScores: [Int]
        let finalContractsCompleted: [Int]
        let actions: ActionTotals
    }

    private struct GameFailure: Codable {
        let playerCount: Int
        let gameNumber: Int
        let seed: UInt64
        let actionCount: Int
        let phase: String
        let message: String
    }

    private struct BatchReport: Codable {
        let generatedAt: String
        let playerCount: Int
        let batchIndex: Int
        let firstGameNumber: Int
        let lastGameNumber: Int
        let gamesRequested: Int
        let gamesCompleted: Int
        let records: [GameRecord]
        let failures: [GameFailure]
    }

    private enum GameOutcome {
        case success(GameRecord)
        case failure(GameFailure)
    }

    func testBatch00() throws { try runBatch(index: 0) }
    func testBatch01() throws { try runBatch(index: 1) }
    func testBatch02() throws { try runBatch(index: 2) }
    func testBatch03() throws { try runBatch(index: 3) }
    func testBatch04() throws { try runBatch(index: 4) }
    func testBatch05() throws { try runBatch(index: 5) }
    func testBatch06() throws { try runBatch(index: 6) }
    func testBatch07() throws { try runBatch(index: 7) }
    func testBatch08() throws { try runBatch(index: 8) }
    func testBatch09() throws { try runBatch(index: 9) }
    func testBatch10() throws { try runBatch(index: 10) }
    func testBatch11() throws { try runBatch(index: 11) }
    func testBatch12() throws { try runBatch(index: 12) }
    func testBatch13() throws { try runBatch(index: 13) }
    func testBatch14() throws { try runBatch(index: 14) }
    func testBatch15() throws { try runBatch(index: 15) }
    func testBatch16() throws { try runBatch(index: 16) }
    func testBatch17() throws { try runBatch(index: 17) }
    func testBatch18() throws { try runBatch(index: 18) }
    func testBatch19() throws { try runBatch(index: 19) }

    private func runBatch(index: Int) throws {
        guard let playerCount = Self.simulationPlayerCount else {
            throw XCTSkip(
                "Run the manual simulation workflow to execute soak batches"
            )
        }

        let firstGameIndex = index * Self.gamesPerBatch
        var records: [GameRecord] = []
        var failures: [GameFailure] = []

        for offset in 0..<Self.gamesPerBatch {
            let gameNumber = firstGameIndex + offset + 1
            let seed =
                UInt64(playerCount) * 1_000_000
                + UInt64(gameNumber)
            switch simulateGame(
                playerCount: playerCount,
                gameNumber: gameNumber,
                seed: seed,
                actionLimit: 100_000
            ) {
            case .success(let record):
                records.append(record)
            case .failure(let failure):
                failures.append(failure)
            }
        }

        let report = BatchReport(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            playerCount: playerCount,
            batchIndex: index,
            firstGameNumber: firstGameIndex + 1,
            lastGameNumber: firstGameIndex + Self.gamesPerBatch,
            gamesRequested: Self.gamesPerBatch,
            gamesCompleted: records.count,
            records: records,
            failures: failures
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        let attachment = XCTAttachment(
            data: data,
            uniformTypeIdentifier: "public.json"
        )
        attachment.name = String(
            format: "game-simulation-%dp-batch-%02d.json",
            playerCount,
            index
        )
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertEqual(
            records.count,
            Self.gamesPerBatch,
            "Every requested game must reach gameEnded"
        )
        XCTAssertTrue(
            failures.isEmpty,
            failures.prefix(10).map {
                "\($0.playerCount)p game \($0.gameNumber): \($0.message)"
            }.joined(separator: "\n")
        )
    }

    private static var simulationPlayerCount: Int? {
        #if RUN_GAME_SIMULATIONS && SIMULATE_PLAYER_COUNT_2
        return 2
        #elseif RUN_GAME_SIMULATIONS && SIMULATE_PLAYER_COUNT_3
        return 3
        #elseif RUN_GAME_SIMULATIONS && SIMULATE_PLAYER_COUNT_4
        return 4
        #elseif RUN_GAME_SIMULATIONS && SIMULATE_PLAYER_COUNT_5
        return 5
        #elseif RUN_GAME_SIMULATIONS && SIMULATE_PLAYER_COUNT_6
        return 6
        #else
        return nil
        #endif
    }

    private func simulateGame(
        playerCount: Int,
        gameNumber: Int,
        seed: UInt64,
        actionLimit: Int
    ) -> GameOutcome {
        let names = (1...playerCount).map { "Bot \($0)" }
        var state = GameFactory.newGame(
            playerNames: names,
            seed: seed
        )
        var actionCount = 0
        var turnCount = 0
        var wentOutHands = 0
        var stockExhaustedHands = 0
        var stockReshuffles = 0
        var maximumHandSize =
            state.players.map(\.hand.count).max() ?? 0
        var actions = ActionTotals()

        while state.phase != .gameEnded,
              actionCount < actionLimit {
            let action: TurnEngine.Action
            if state.phase == .roundEnded {
                action = .advanceHand(playerId: state.nextDealer.id)
            } else {
                action = CPUPlayer.nextAction(
                    for: state.activePlayerId,
                    in: state
                )
            }

            let previous = state
            actions.record(action, in: previous)
            switch TurnEngine.apply(action, to: previous) {
            case .failure(let error):
                return .failure(
                    GameFailure(
                        playerCount: playerCount,
                        gameNumber: gameNumber,
                        seed: seed,
                        actionCount: actionCount,
                        phase: previous.phase.rawValue,
                        message: "\(error.description); action: \(action)"
                    )
                )
            case .success(let next):
                actionCount += 1
                if case .discard = action {
                    turnCount += 1
                }
                if next.currentRound == previous.currentRound,
                   next.stockReshufflesUsed
                    > previous.stockReshufflesUsed {
                    stockReshuffles +=
                        next.stockReshufflesUsed
                        - previous.stockReshufflesUsed
                }
                let handJustEnded =
                    previous.phase != .roundEnded
                    && previous.phase != .gameEnded
                    && (next.phase == .roundEnded
                        || next.phase == .gameEnded)
                if handJustEnded {
                    let someoneWentOut = next.players.contains {
                        $0.hand.isEmpty && $0.hasGoneDownThisRound
                    }
                    if someoneWentOut {
                        wentOutHands += 1
                    } else {
                        stockExhaustedHands += 1
                    }
                }
                maximumHandSize = max(
                    maximumHandSize,
                    next.players.map(\.hand.count).max() ?? 0
                )
                state = next
            }
        }

        guard state.phase == .gameEnded else {
            return .failure(
                GameFailure(
                    playerCount: playerCount,
                    gameNumber: gameNumber,
                    seed: seed,
                    actionCount: actionCount,
                    phase: state.phase.rawValue,
                    message: "Exceeded \(actionLimit) actions"
                )
            )
        }

        let winnerIds = Set(state.gameWinnerIds)
        return .success(
            GameRecord(
                playerCount: playerCount,
                gameNumber: gameNumber,
                seed: seed,
                actionCount: actionCount,
                turnCount: turnCount,
                hands: state.currentRound,
                wentOutHands: wentOutHands,
                stockExhaustedHands: stockExhaustedHands,
                stockReshuffles: stockReshuffles,
                maximumHandSize: maximumHandSize,
                winnerSeats: state.players.indices.filter {
                    winnerIds.contains(state.players[$0].id)
                },
                finalScores: state.players.map(\.totalScore),
                finalContractsCompleted: state.players.map {
                    min(
                        RulesConfig.maxLevel,
                        max(0, $0.currentLevel - 1)
                    )
                },
                actions: actions
            )
        )
    }
}
