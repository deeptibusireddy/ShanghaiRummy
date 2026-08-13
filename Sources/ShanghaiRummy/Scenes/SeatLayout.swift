import CoreGraphics
import Foundation

/// Computes seat positions around the table for 2-6 players.
///
/// Seat 0 is always the "you" seat at the bottom (or nearest to bottom).
/// Remaining seats fan around the table in the order they were dealt.
///
/// All returned points are in scene coordinates (origin bottom-left, size
/// == scene.size). The layout is derived once per rebuild and does not
/// depend on SpriteKit — pure math, unit-testable.
enum SeatLayout {
    static let topCornerXFraction: CGFloat = 0.135

    /// A single seat's placement on the table.
    struct Seat: Equatable {
        /// Anchor point for the seat's name label / meld row (in scene coords).
        var anchor: CGPoint
        /// Which edge the seat hugs. Used to rotate labels & orient meld rows.
        var edge: Edge
    }

    enum Edge: String, Equatable {
        case bottom, top, left, right, topLeft, topRight
    }

    /// Returns seat placements in the ORDER players appear in `GameState.players`,
    /// with the "you" player (index `youIndex`) rotated to position 0 (bottom).
    static func seats(
        playerCount: Int,
        youIndex: Int,
        sceneSize: CGSize,
        insets: CGFloat = 24
    ) -> [Seat] {
        precondition(playerCount >= 2 && playerCount <= 6, "Only 2-6 seats supported")
        precondition(youIndex >= 0 && youIndex < playerCount, "youIndex out of range")

        // Position templates keyed by count; "you" is always seat[0].
        let templates: [[Seat]]
        let w = sceneSize.width
        let h = sceneSize.height
        let midX = w / 2
        let leftX = insets + 60
        let rightX = w - insets - 60
        // Leave room for the 48pt turn ribbon and the device safe area.
        let topY = h - insets - 60
        let botY = insets + 60
        let quarterLeft = w * topCornerXFraction
        let quarterRight = w * (1 - topCornerXFraction)

        switch playerCount {
        case 2:
            templates = [[
                Seat(anchor: CGPoint(x: midX, y: botY), edge: .bottom),
                Seat(anchor: CGPoint(x: midX, y: topY), edge: .top),
            ]]
        case 3:
            templates = [[
                Seat(anchor: CGPoint(x: midX, y: botY), edge: .bottom),
                Seat(anchor: CGPoint(x: leftX, y: h / 2), edge: .left),
                Seat(anchor: CGPoint(x: midX, y: topY), edge: .top),
            ]]
        case 4:
            templates = [[
                Seat(anchor: CGPoint(x: midX, y: botY), edge: .bottom),
                Seat(anchor: CGPoint(x: leftX, y: h / 2), edge: .left),
                Seat(anchor: CGPoint(x: midX, y: topY), edge: .top),
                Seat(anchor: CGPoint(x: rightX, y: h / 2), edge: .right),
            ]]
        case 5:
            templates = [[
                Seat(anchor: CGPoint(x: midX, y: botY), edge: .bottom),
                Seat(anchor: CGPoint(x: leftX, y: h / 2), edge: .left),
                Seat(anchor: CGPoint(x: quarterLeft, y: topY), edge: .topLeft),
                Seat(anchor: CGPoint(x: quarterRight, y: topY), edge: .topRight),
                Seat(anchor: CGPoint(x: rightX, y: h / 2), edge: .right),
            ]]
        case 6:
            templates = [[
                Seat(anchor: CGPoint(x: midX, y: botY), edge: .bottom),
                Seat(anchor: CGPoint(x: leftX, y: h / 2), edge: .left),
                Seat(anchor: CGPoint(x: quarterLeft, y: topY), edge: .topLeft),
                Seat(anchor: CGPoint(x: midX, y: topY), edge: .top),
                Seat(anchor: CGPoint(x: quarterRight, y: topY), edge: .topRight),
                Seat(anchor: CGPoint(x: rightX, y: h / 2), edge: .right),
            ]]
        default:
            templates = [[]]
        }

        // The template gives seats in visual order starting from bottom.
        // Rotate the player list so player `youIndex` maps to seat 0.
        // We want to preserve turn order visually — the player after "you" sits
        // to your left, next around the table, etc.
        var seats = Array(repeating: templates[0][0], count: playerCount)
        for i in 0..<playerCount {
            let playerIndex = (youIndex + i) % playerCount
            seats[playerIndex] = templates[0][i]
        }
        return seats
    }

    /// Center point of the shared piles (stock + discard). Sits just above
    /// midline so the top-seat opponent has room to render its seat card and
    /// mini-meld strip above the piles, and the bottom half stays clear for
    /// the current player's hand + HUD.
    static func pileCenter(sceneSize: CGSize) -> CGPoint {
        CGPoint(x: sceneSize.width / 2,
                y: max(220, sceneSize.height * 0.565))
    }
}
