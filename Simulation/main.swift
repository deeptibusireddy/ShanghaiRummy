import Foundation
import ShanghaiRummyCore

#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

struct Arguments {
    let playerCount: Int
    let firstGameNumber: Int
    let gameCount: Int
    let outputPath: String

    static func parse() -> Arguments? {
        var values: [String: String] = [:]
        var index = 1
        while index + 1 < CommandLine.arguments.count {
            values[CommandLine.arguments[index]] =
                CommandLine.arguments[index + 1]
            index += 2
        }
        guard let playerCount = Int(values["--players"] ?? ""),
              let firstGameNumber = Int(values["--start"] ?? ""),
              let gameCount = Int(values["--count"] ?? ""),
              let outputPath = values["--output"],
              (RulesConfig.minPlayers...RulesConfig.maxPlayers)
                .contains(playerCount),
              firstGameNumber > 0,
              gameCount > 0 else {
            return nil
        }
        return Arguments(
            playerCount: playerCount,
            firstGameNumber: firstGameNumber,
            gameCount: gameCount,
            outputPath: outputPath
        )
    }
}

struct ActionTotals: Codable {
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

struct GameRecord: Codable {
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

struct GameFailure: Codable {
    let playerCount: Int
    let gameNumber: Int
    let seed: UInt64
    let actionCount: Int
    let currentRound: Int
    let phase: String
    let playerLevels: [Int]
    let playerHandSizes: [Int]
    let playerBuysUsed: [Int]
    let playersGoneDown: [Bool]
    let stockCount: Int
    let discardCount: Int
    let meldCount: Int
    let stockReshufflesUsed: Int
    let message: String
}

struct BatchReport: Codable {
    let generatedAt: String
    let playerCount: Int
    let firstGameNumber: Int
    let lastGameNumber: Int
    let gamesRequested: Int
    let gamesCompleted: Int
    let records: [GameRecord]
    let failures: [GameFailure]
}

enum GameOutcome {
    case success(GameRecord)
    case failure(GameFailure)
}

func gameFailure(
    playerCount: Int,
    gameNumber: Int,
    seed: UInt64,
    actionCount: Int,
    state: GameState,
    message: String
) -> GameFailure {
    GameFailure(
        playerCount: playerCount,
        gameNumber: gameNumber,
        seed: seed,
        actionCount: actionCount,
        currentRound: state.currentRound,
        phase: state.phase.rawValue,
        playerLevels: state.players.map(\.currentLevel),
        playerHandSizes: state.players.map(\.hand.count),
        playerBuysUsed: state.players.map(\.buysUsedThisRound),
        playersGoneDown: state.players.map(\.hasGoneDownThisRound),
        stockCount: state.stock.count,
        discardCount: state.discard.count,
        meldCount: state.melds.count,
        stockReshufflesUsed: state.stockReshufflesUsed,
        message: message
    )
}

func simulateGame(
    playerCount: Int,
    gameNumber: Int,
    seed: UInt64,
    actionLimit: Int = 10_000
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
                gameFailure(
                    playerCount: playerCount,
                    gameNumber: gameNumber,
                    seed: seed,
                    actionCount: actionCount,
                    state: previous,
                    message: "\(error.description); action: \(action)"
                )
            )
        case .success(let next):
            actionCount += 1
            if case .discard = action {
                turnCount += 1
            }
            if next.currentRound == previous.currentRound,
               next.stockReshufflesUsed > previous.stockReshufflesUsed {
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
            gameFailure(
                playerCount: playerCount,
                gameNumber: gameNumber,
                seed: seed,
                actionCount: actionCount,
                state: state,
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

guard let arguments = Arguments.parse() else {
    fputs(
        "Usage: GameSimulationCLI --players 2...6 --start N "
            + "--count N --output report.json\n",
        stderr
    )
    exit(EXIT_FAILURE)
}

var records: [GameRecord] = []
var failures: [GameFailure] = []
let lastGameNumber =
    arguments.firstGameNumber + arguments.gameCount - 1

for gameNumber in arguments.firstGameNumber...lastGameNumber {
    let seed =
        UInt64(arguments.playerCount) * 1_000_000
        + UInt64(gameNumber)
    switch simulateGame(
        playerCount: arguments.playerCount,
        gameNumber: gameNumber,
        seed: seed
    ) {
    case .success(let record):
        records.append(record)
    case .failure(let failure):
        failures.append(failure)
    }
}

let report = BatchReport(
    generatedAt: ISO8601DateFormatter().string(from: Date()),
    playerCount: arguments.playerCount,
    firstGameNumber: arguments.firstGameNumber,
    lastGameNumber: lastGameNumber,
    gamesRequested: arguments.gameCount,
    gamesCompleted: records.count,
    records: records,
    failures: failures
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

do {
    let outputURL = URL(fileURLWithPath: arguments.outputPath)
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try encoder.encode(report).write(to: outputURL)
} catch {
    fputs("Could not write simulation report: \(error)\n", stderr)
    exit(EXIT_FAILURE)
}

guard failures.isEmpty,
      records.count == arguments.gameCount else {
    for failure in failures.prefix(10) {
        fputs(
            "\(failure.playerCount)p game \(failure.gameNumber): "
                + "\(failure.message)\n",
            stderr
        )
    }
    exit(EXIT_FAILURE)
}

print(
    "\(arguments.playerCount)-player games "
        + "\(arguments.firstGameNumber)-\(lastGameNumber) completed"
)
