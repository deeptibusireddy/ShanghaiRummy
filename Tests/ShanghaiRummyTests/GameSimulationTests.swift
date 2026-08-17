import Foundation
import XCTest
@testable import ShanghaiRummy

final class GameSimulationTests: XCTestCase {
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

        static func += (lhs: inout ActionTotals, rhs: ActionTotals) {
            lhs.stockChoices += rhs.stockChoices
            lhs.discardTakes += rhs.discardTakes
            lhs.contractsLaid += rhs.contractsLaid
            lhs.cardsLaidOff += rhs.cardsLaidOff
            lhs.wildRedemptions += rhs.wildRedemptions
            lhs.discards += rhs.discards
            lhs.outOfTurnBuys += rhs.outOfTurnBuys
            lhs.outOfTurnPasses += rhs.outOfTurnPasses
            lhs.handsAdvanced += rhs.handsAdvanced
        }
    }

    private struct GameMetrics {
        var actionCount = 0
        var turnCount = 0
        var hands = 0
        var wentOutHands = 0
        var stockExhaustedHands = 0
        var stockReshuffles = 0
        var maximumHandSize = 0
        var winnerSeats: [Int] = []
        var finalScores: [Int] = []
        var finalContractsCompleted: [Int] = []
        var actions = ActionTotals()
    }

    private enum GameOutcome {
        case success(GameMetrics)
        case failure(message: String, actionCount: Int, phase: GameState.Phase)
    }

    private struct SimulationFailure: Codable {
        let playerCount: Int
        let gameNumber: Int
        let seed: UInt64
        let actionCount: Int
        let phase: String
        let message: String
    }

    private struct PlayerCountResult: Codable {
        let playerCount: Int
        let gamesRequested: Int
        let gamesCompleted: Int
        let gamesFailed: Int
        let averageActionsPerGame: Double
        let p95ActionsPerGame: Int
        let maximumActionsPerGame: Int
        let averageHandsPerGame: Double
        let p95HandsPerGame: Int
        let maximumHandsPerGame: Int
        let averageTurnsPerGame: Double
        let averageMaximumHandSize: Double
        let averageContractGapAtFinish: Double
        let wentOutHands: Int
        let stockExhaustedHands: Int
        let stockExhaustionPercentOfHands: Double
        let stockReshuffles: Int
        let coWinnerGames: Int
        let winnerSeatCounts: [Int]
        let averageFinalScoreBySeat: [Double]
        let averageContractsCompletedBySeat: [Double]
        let discardTakePercent: Double
        let outOfTurnBuyAcceptancePercent: Double
        let actions: ActionTotals
    }

    private struct SimulationReport: Codable {
        let generatedAt: String
        let gamesPerPlayerCount: Int
        let totalGamesRequested: Int
        let totalGamesCompleted: Int
        let results: [PlayerCountResult]
        let failures: [SimulationFailure]
    }

    private struct PlayerCountAccumulator {
        let playerCount: Int
        let gamesRequested: Int
        var completed = 0
        var actionCounts: [Int] = []
        var handCounts: [Int] = []
        var turnCounts: [Int] = []
        var maximumHandSizes: [Int] = []
        var contractGaps: [Int] = []
        var wentOutHands = 0
        var stockExhaustedHands = 0
        var stockReshuffles = 0
        var coWinnerGames = 0
        var winnerSeatCounts: [Int]
        var finalScoreSums: [Int]
        var finalContractSums: [Int]
        var actions = ActionTotals()

        init(playerCount: Int, gamesRequested: Int) {
            self.playerCount = playerCount
            self.gamesRequested = gamesRequested
            winnerSeatCounts = Array(repeating: 0, count: playerCount)
            finalScoreSums = Array(repeating: 0, count: playerCount)
            finalContractSums = Array(repeating: 0, count: playerCount)
        }

        mutating func record(_ metrics: GameMetrics) {
            completed += 1
            actionCounts.append(metrics.actionCount)
            handCounts.append(metrics.hands)
            turnCounts.append(metrics.turnCount)
            maximumHandSizes.append(metrics.maximumHandSize)
            let maxContracts =
                metrics.finalContractsCompleted.max() ?? 0
            let minContracts =
                metrics.finalContractsCompleted.min() ?? 0
            contractGaps.append(maxContracts - minContracts)
            wentOutHands += metrics.wentOutHands
            stockExhaustedHands += metrics.stockExhaustedHands
            stockReshuffles += metrics.stockReshuffles
            if metrics.winnerSeats.count > 1 {
                coWinnerGames += 1
            }
            for seat in metrics.winnerSeats {
                winnerSeatCounts[seat] += 1
            }
            for seat in 0..<playerCount {
                finalScoreSums[seat] += metrics.finalScores[seat]
                finalContractSums[seat] +=
                    metrics.finalContractsCompleted[seat]
            }
            actions += metrics.actions
        }

        func result(failureCount: Int) -> PlayerCountResult {
            let totalEndedHands = wentOutHands + stockExhaustedHands
            let firstRefusalChoices =
                actions.stockChoices + actions.discardTakes
            let buyDecisions =
                actions.outOfTurnBuys + actions.outOfTurnPasses
            return PlayerCountResult(
                playerCount: playerCount,
                gamesRequested: gamesRequested,
                gamesCompleted: completed,
                gamesFailed: failureCount,
                averageActionsPerGame:
                    GameSimulationTests.average(actionCounts),
                p95ActionsPerGame:
                    GameSimulationTests.percentile(actionCounts, 0.95),
                maximumActionsPerGame: actionCounts.max() ?? 0,
                averageHandsPerGame:
                    GameSimulationTests.average(handCounts),
                p95HandsPerGame:
                    GameSimulationTests.percentile(handCounts, 0.95),
                maximumHandsPerGame: handCounts.max() ?? 0,
                averageTurnsPerGame:
                    GameSimulationTests.average(turnCounts),
                averageMaximumHandSize:
                    GameSimulationTests.average(maximumHandSizes),
                averageContractGapAtFinish:
                    GameSimulationTests.average(contractGaps),
                wentOutHands: wentOutHands,
                stockExhaustedHands: stockExhaustedHands,
                stockExhaustionPercentOfHands: GameSimulationTests.percent(
                    stockExhaustedHands,
                    totalEndedHands
                ),
                stockReshuffles: stockReshuffles,
                coWinnerGames: coWinnerGames,
                winnerSeatCounts: winnerSeatCounts,
                averageFinalScoreBySeat: GameSimulationTests.averages(
                    finalScoreSums,
                    denominator: completed
                ),
                averageContractsCompletedBySeat:
                    GameSimulationTests.averages(
                        finalContractSums,
                        denominator: completed
                    ),
                discardTakePercent: GameSimulationTests.percent(
                    actions.discardTakes,
                    firstRefusalChoices
                ),
                outOfTurnBuyAcceptancePercent:
                    GameSimulationTests.percent(
                        actions.outOfTurnBuys,
                        buyDecisions
                    ),
                actions: actions
            )
        }
    }

    func testFiveThousandBotGamesComplete() throws {
        guard ProcessInfo.processInfo.environment[
            "RUN_GAME_SIMULATIONS"
        ] == "1" else {
            throw XCTSkip(
                "Set RUN_GAME_SIMULATIONS=1 to run the 2–6 player soak suite"
            )
        }

        let gamesPerPlayerCount = Int(
            ProcessInfo.processInfo.environment[
                "GAMES_PER_PLAYER_COUNT"
            ] ?? ""
        ) ?? 1_000
        let actionLimitPerGame = 100_000
        var failures: [SimulationFailure] = []
        var results: [PlayerCountResult] = []

        for playerCount in RulesConfig.minPlayers...RulesConfig.maxPlayers {
            var accumulator = PlayerCountAccumulator(
                playerCount: playerCount,
                gamesRequested: gamesPerPlayerCount
            )
            let failureStart = failures.count

            for gameIndex in 0..<gamesPerPlayerCount {
                let seed =
                    UInt64(playerCount) * 1_000_000
                    + UInt64(gameIndex + 1)
                switch simulateGame(
                    playerCount: playerCount,
                    seed: seed,
                    actionLimit: actionLimitPerGame
                ) {
                case .success(let metrics):
                    accumulator.record(metrics)
                case .failure(let message, let actionCount, let phase):
                    failures.append(
                        SimulationFailure(
                            playerCount: playerCount,
                            gameNumber: gameIndex + 1,
                            seed: seed,
                            actionCount: actionCount,
                            phase: phase.rawValue,
                            message: message
                        )
                    )
                }

                if (gameIndex + 1).isMultiple(of: 100) {
                    print(
                        "Simulation progress: \(playerCount) players, "
                            + "\(gameIndex + 1)/\(gamesPerPlayerCount) games"
                    )
                }
            }

            results.append(
                accumulator.result(
                    failureCount: failures.count - failureStart
                )
            )
        }

        let report = SimulationReport(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            gamesPerPlayerCount: gamesPerPlayerCount,
            totalGamesRequested:
                gamesPerPlayerCount
                * (RulesConfig.maxPlayers - RulesConfig.minPlayers + 1),
            totalGamesCompleted: results.reduce(0) {
                $0 + $1.gamesCompleted
            },
            results: results,
            failures: failures
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        let attachment = XCTAttachment(
            data: data,
            uniformTypeIdentifier: "public.json"
        )
        attachment.name = "game-simulation-report.json"
        attachment.lifetime = .keepAlways
        add(attachment)
        print(
            "SIMULATION_REPORT_BASE64:"
                + data.base64EncodedString()
        )

        XCTAssertEqual(
            report.totalGamesCompleted,
            report.totalGamesRequested,
            "Every requested game must reach gameEnded"
        )
        XCTAssertTrue(
            failures.isEmpty,
            failures.prefix(10).map {
                "\($0.playerCount)p game \($0.gameNumber): \($0.message)"
            }.joined(separator: "\n")
        )
    }

    private func simulateGame(
        playerCount: Int,
        seed: UInt64,
        actionLimit: Int
    ) -> GameOutcome {
        let names = (1...playerCount).map { "Bot \($0)" }
        var state = GameFactory.newGame(
            playerNames: names,
            seed: seed
        )
        var metrics = GameMetrics()
        metrics.maximumHandSize =
            state.players.map(\.hand.count).max() ?? 0

        while state.phase != .gameEnded,
              metrics.actionCount < actionLimit {
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
            metrics.actions.record(action, in: previous)
            switch TurnEngine.apply(action, to: previous) {
            case .failure(let error):
                return .failure(
                    message: "\(error.description); action: \(action)",
                    actionCount: metrics.actionCount,
                    phase: previous.phase
                )
            case .success(let next):
                metrics.actionCount += 1
                if case .discard = action {
                    metrics.turnCount += 1
                }
                if next.currentRound == previous.currentRound,
                   next.stockReshufflesUsed
                    > previous.stockReshufflesUsed {
                    metrics.stockReshuffles +=
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
                        metrics.wentOutHands += 1
                    } else {
                        metrics.stockExhaustedHands += 1
                    }
                }
                metrics.maximumHandSize = max(
                    metrics.maximumHandSize,
                    next.players.map(\.hand.count).max() ?? 0
                )
                state = next
            }
        }

        guard state.phase == .gameEnded else {
            return .failure(
                message: "Exceeded \(actionLimit) actions",
                actionCount: metrics.actionCount,
                phase: state.phase
            )
        }

        let winnerIds = Set(state.gameWinnerIds)
        metrics.hands = state.currentRound
        metrics.winnerSeats = state.players.indices.filter {
            winnerIds.contains(state.players[$0].id)
        }
        metrics.finalScores = state.players.map(\.totalScore)
        metrics.finalContractsCompleted = state.players.map {
            min(
                RulesConfig.maxLevel,
                max(0, $0.currentLevel - 1)
            )
        }
        return .success(metrics)
    }

    private static func average(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        return rounded(
            Double(values.reduce(0, +)) / Double(values.count)
        )
    }

    private static func averages(
        _ values: [Int],
        denominator: Int
    ) -> [Double] {
        guard denominator > 0 else {
            return Array(repeating: 0, count: values.count)
        }
        return values.map {
            rounded(Double($0) / Double(denominator))
        }
    }

    private static func percentile(
        _ values: [Int],
        _ percentile: Double
    ) -> Int {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = Int(
            (Double(sorted.count - 1) * percentile).rounded(.up)
        )
        return sorted[index]
    }

    private static func percent(
        _ numerator: Int,
        _ denominator: Int
    ) -> Double {
        guard denominator > 0 else { return 0 }
        return rounded(
            Double(numerator) * 100 / Double(denominator)
        )
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
