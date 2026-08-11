import Foundation

/// A single-source-of-truth Codable snapshot of the entire game.
///
/// Serialize this to bytes for GameKit messages and local persistence.
/// All state transitions go through `TurnEngine.apply(_:to:)`.
public struct GameState: Codable, Sendable, Equatable {
    public var players: [Player]
    /// The nth hand being played (1, 2, 3, ...). NOTE: this is NOT the
    /// contract level. Each player has their own `currentLevel`. This field
    /// just tracks how many hands have been dealt in this match.
    public var currentRound: Int
    public var currentTurnIndex: Int      // index into `players`
    public var dealerIndex: Int
    public var stock: [Card]              // face-down draw pile; top = last element
    public var discard: [Card]            // face-up pile; top = last element
    public var melds: [Meld]              // all melds on the table (all players)
    public var phase: Phase
    public var stockReshufflesUsed: Int   // for "exhausted twice" round end
    /// Deterministic RNG seed for this match. Shared across clients so shuffles
    /// reproduce identically.
    public var randomSeed: UInt64
    /// Populated when `phase == .gameEnded`. Usually one player, but can be
    /// multiple when they finish level 10 in the same hand and tie on
    /// cumulative score.
    public var gameWinnerIds: [UUID]
    /// Out-of-turn players who announced "Buy" before the turn player draws.
    /// Resolution uses table order, not request arrival order.
    public var buyRequestPlayerIds: [UUID]

    private enum CodingKeys: String, CodingKey {
        case players
        case currentRound
        case currentTurnIndex
        case dealerIndex
        case stock
        case discard
        case melds
        case phase
        case stockReshufflesUsed
        case randomSeed
        case gameWinnerIds
        case buyRequestPlayerIds
    }

    public enum Phase: String, Codable, Sendable {
        case awaitingDraw
        case awaitingMeldOrDiscard
        case roundEnded
        case gameEnded
    }

    public var currentPlayerId: UUID { players[currentTurnIndex].id }
    /// Contract for the current turn player based on their own level.
    /// Independent-contract variant: each player is on their own 1-10 track.
    public var currentContract: Contract? {
        RoundSchedule.contract(forRound: players[currentTurnIndex].currentLevel)
    }
    public func contract(forPlayer id: UUID) -> Contract? {
        guard let p = players.first(where: { $0.id == id }) else { return nil }
        return RoundSchedule.contract(forRound: p.currentLevel)
    }
    public var prioritizedBuyRequesterId: UUID? {
        guard players.count > 1 else { return nil }
        let requested = Set(buyRequestPlayerIds)
        for offset in 1..<players.count {
            let index = (currentTurnIndex + offset) % players.count
            let player = players[index]
            if requested.contains(player.id),
               player.buysUsedThisRound < RulesConfig.maxBuysPerRound {
                return player.id
            }
        }
        return nil
    }

    public init(
        players: [Player],
        currentRound: Int,
        currentTurnIndex: Int,
        dealerIndex: Int,
        stock: [Card],
        discard: [Card],
        melds: [Meld],
        phase: Phase,
        stockReshufflesUsed: Int,
        randomSeed: UInt64,
        gameWinnerIds: [UUID] = [],
        buyRequestPlayerIds: [UUID] = []
    ) {
        self.players = players
        self.currentRound = currentRound
        self.currentTurnIndex = currentTurnIndex
        self.dealerIndex = dealerIndex
        self.stock = stock
        self.discard = discard
        self.melds = melds
        self.phase = phase
        self.stockReshufflesUsed = stockReshufflesUsed
        self.randomSeed = randomSeed
        self.gameWinnerIds = gameWinnerIds
        self.buyRequestPlayerIds = buyRequestPlayerIds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        players = try container.decode([Player].self, forKey: .players)
        currentRound = try container.decode(Int.self, forKey: .currentRound)
        currentTurnIndex = try container.decode(Int.self, forKey: .currentTurnIndex)
        dealerIndex = try container.decode(Int.self, forKey: .dealerIndex)
        stock = try container.decode([Card].self, forKey: .stock)
        discard = try container.decode([Card].self, forKey: .discard)
        melds = try container.decode([Meld].self, forKey: .melds)
        phase = try container.decode(Phase.self, forKey: .phase)
        stockReshufflesUsed = try container.decode(
            Int.self,
            forKey: .stockReshufflesUsed
        )
        randomSeed = try container.decode(UInt64.self, forKey: .randomSeed)
        gameWinnerIds = try container.decode(
            [UUID].self,
            forKey: .gameWinnerIds
        )
        buyRequestPlayerIds = try container.decodeIfPresent(
            [UUID].self,
            forKey: .buyRequestPlayerIds
        ) ?? []
    }
}
