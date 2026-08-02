import Foundation

/// End-of-round scoring per the family ruleset.
/// See `docs/rules.md` — cards left in hand count as penalty; the go-out player
/// scores 0; no bonus.
public enum Scoring {
    /// Total penalty for a hand of cards.
    public static func penalty(for hand: [Card]) -> Int {
        hand.reduce(0) { $0 + $1.points }
    }

    /// Score every player at end of round. The `wentOutPlayerId` scores 0;
    /// every other player scores the sum of `card.points` for cards in hand.
    /// Result maps player IDs to points added *for this round* (not cumulative).
    public static func endOfRound(
        players: [Player],
        wentOutPlayerId: UUID?
    ) -> [UUID: Int] {
        var results: [UUID: Int] = [:]
        for player in players {
            if player.id == wentOutPlayerId {
                results[player.id] = 0
            } else {
                results[player.id] = penalty(for: player.hand)
            }
        }
        return results
    }
}
