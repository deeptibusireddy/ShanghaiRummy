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
    /// Legacy simultaneous-buy state retained only so older snapshots decode.
    /// New games use `buyDecisionPlayerId` for sequential clockwise offers.
    public var buyRequestPlayerIds: [UUID]
    /// Player currently deciding whether to take or pass the top discard.
    /// The turn player decides first; eligible buyers then decide clockwise.
    public var buyDecisionPlayerId: UUID?
    /// Cards visually marked as newly added, tracked separately for each
    /// private hand. Purchase cards survive until that buyer's official draw;
    /// the official draw remains highlighted only for that turn.
    public var highlightedCardIdsByPlayer: [UUID: [UUID]]

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
        case buyDecisionPlayerId
        case highlightedCardIdsByPlayer
    }

    public enum Phase: String, Codable, Sendable {
        case awaitingDraw
        case awaitingMeldOrDiscard
        case roundEnded
        case gameEnded
    }

    public var currentPlayerId: UUID { players[currentTurnIndex].id }
    public var nextDealerIndex: Int { (dealerIndex + 1) % players.count }
    public var nextDealer: Player { players[nextDealerIndex] }
    /// Contract for the current turn player based on their own level.
    /// Independent-contract variant: each player is on their own 1-10 track.
    public var currentContract: Contract? {
        RoundSchedule.contract(forRound: players[currentTurnIndex].currentLevel)
    }
    public func contract(forPlayer id: UUID) -> Contract? {
        guard let p = players.first(where: { $0.id == id }) else { return nil }
        return RoundSchedule.contract(forRound: p.currentLevel)
    }
    public var activePlayerId: UUID {
        if phase == .awaitingDraw, let buyDecisionPlayerId {
            return buyDecisionPlayerId
        }
        return currentPlayerId
    }
    public var buyDecisionPlayer: Player? {
        guard let buyDecisionPlayerId else { return nil }
        return players.first(where: { $0.id == buyDecisionPlayerId })
    }
    public func isEligibleBuyer(_ player: Player) -> Bool {
        stock.count > RulesConfig.penaltyCardsOnBuy
            && player.id != currentPlayerId
            && !player.hasGoneDownThisRound
            && player.buysUsedThisRound < RulesConfig.maxBuysPerRound
    }
    public func nextEligibleBuyer(after playerId: UUID) -> UUID? {
        guard players.count > 1,
              let startIndex = players.firstIndex(where: {
                  $0.id == playerId
              }) else {
            return nil
        }

        for offset in 1..<players.count {
            let index = (startIndex + offset) % players.count
            if index == currentTurnIndex {
                return nil
            }
            let player = players[index]
            if isEligibleBuyer(player) {
                return player.id
            }
        }
        return nil
    }

    public func highlightedCardIds(for playerId: UUID) -> Set<UUID> {
        Set(highlightedCardIdsByPlayer[playerId] ?? [])
    }

    mutating func replaceHighlightedCards(
        for playerId: UUID,
        with cards: [Card]
    ) {
        highlightedCardIdsByPlayer[playerId] = cards.map(\.id)
    }

    mutating func appendHighlightedCards(
        for playerId: UUID,
        cards: [Card]
    ) {
        var ids = highlightedCardIdsByPlayer[playerId] ?? []
        let existing = Set(ids)
        ids.append(contentsOf: cards.map(\.id).filter { !existing.contains($0) })
        highlightedCardIdsByPlayer[playerId] = ids
    }

    mutating func clearHighlightedCards(for playerId: UUID) {
        highlightedCardIdsByPlayer.removeValue(forKey: playerId)
    }

    mutating func removeHighlightedCards(
        for playerId: UUID,
        cardIds: Set<UUID>
    ) {
        guard let ids = highlightedCardIdsByPlayer[playerId] else { return }
        let remaining = ids.filter { !cardIds.contains($0) }
        if remaining.isEmpty {
            highlightedCardIdsByPlayer.removeValue(forKey: playerId)
        } else {
            highlightedCardIdsByPlayer[playerId] = remaining
        }
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
        buyRequestPlayerIds: [UUID] = [],
        buyDecisionPlayerId: UUID? = nil,
        highlightedCardIdsByPlayer: [UUID: [UUID]] = [:]
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
        self.buyDecisionPlayerId = buyDecisionPlayerId
            ?? Self.initialBuyDecisionPlayerId(
                players: players,
                currentTurnIndex: currentTurnIndex,
                phase: phase
            )
        self.highlightedCardIdsByPlayer = highlightedCardIdsByPlayer
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
        buyDecisionPlayerId = try container.decodeIfPresent(
            UUID.self,
            forKey: .buyDecisionPlayerId
        ) ?? Self.initialBuyDecisionPlayerId(
            players: players,
            currentTurnIndex: currentTurnIndex,
            phase: phase
        )
        highlightedCardIdsByPlayer = try container.decodeIfPresent(
            [UUID: [UUID]].self,
            forKey: .highlightedCardIdsByPlayer
        ) ?? [:]
    }

    private static func initialBuyDecisionPlayerId(
        players: [Player],
        currentTurnIndex: Int,
        phase: Phase
    ) -> UUID? {
        guard phase == .awaitingDraw,
              players.indices.contains(currentTurnIndex) else {
            return nil
        }
        return players[currentTurnIndex].id
    }
}
