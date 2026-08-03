import SpriteKit

/// A single card sprite. Renders a real card face — corner rank+suit pip
/// top-left + bottom-right, a large centered suit glyph — or a themed
/// card back when `faceUp == false`. Jokers get a star; wild 2s get a
/// small "★" badge; dead 2s get a "†".
///
/// Colors and fonts come from the passed-in `VisualTheme` so the same
/// scene can be reskinned by swapping themes.
final class CardNode: SKNode {

    static let size = CGSize(width: 60, height: 84)

    let card: Card
    private let theme: VisualTheme

    init(card: Card, faceUp: Bool = true, theme: VisualTheme = .cozyWood) {
        self.card = card
        self.theme = theme
        super.init()
        buildFace(faceUp: faceUp)
        isUserInteractionEnabled = false
        name = "card:\(card.id.uuidString)"
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Rendering

    private func buildFace(faceUp: Bool) {
        let rect = CGRect(
            origin: CGPoint(x: -Self.size.width / 2, y: -Self.size.height / 2),
            size: Self.size
        )
        let bg = SKShapeNode(rect: rect, cornerRadius: 8)
        bg.strokeColor = theme.cardStroke
        bg.lineWidth = 1
        addChild(bg)

        if !faceUp {
            bg.fillColor = theme.cardBack
            addBackPattern(rect: rect)
            return
        }

        bg.fillColor = theme.cardFace
        let color = suitColor()
        let (rank, suit) = glyphs()

        // Top-left corner pip: rank on top, tiny suit below.
        let cornerRank = SKLabelNode(text: rank)
        cornerRank.fontName = theme.titleFont
        cornerRank.fontSize = 14
        cornerRank.fontColor = color
        cornerRank.horizontalAlignmentMode = .left
        cornerRank.verticalAlignmentMode = .top
        cornerRank.position = CGPoint(x: rect.minX + 5, y: rect.maxY - 4)
        addChild(cornerRank)

        let cornerSuit = SKLabelNode(text: suit)
        cornerSuit.fontName = theme.bodyFont
        cornerSuit.fontSize = 11
        cornerSuit.fontColor = color
        cornerSuit.horizontalAlignmentMode = .left
        cornerSuit.verticalAlignmentMode = .top
        cornerSuit.position = CGPoint(x: rect.minX + 5, y: rect.maxY - 20)
        addChild(cornerSuit)

        // Bottom-right corner pip: rotated 180°.
        let brContainer = SKNode()
        brContainer.zRotation = .pi
        brContainer.position = CGPoint(x: rect.maxX - 5, y: rect.minY + 4)
        let brRank = SKLabelNode(text: rank)
        brRank.fontName = theme.titleFont
        brRank.fontSize = 14
        brRank.fontColor = color
        brRank.horizontalAlignmentMode = .left
        brRank.verticalAlignmentMode = .top
        brContainer.addChild(brRank)
        let brSuit = SKLabelNode(text: suit)
        brSuit.fontName = theme.bodyFont
        brSuit.fontSize = 11
        brSuit.fontColor = color
        brSuit.horizontalAlignmentMode = .left
        brSuit.verticalAlignmentMode = .top
        brSuit.position = CGPoint(x: 0, y: -16)
        brContainer.addChild(brSuit)
        addChild(brContainer)

        // Center glyph: big suit (or a star for the joker).
        let center = SKLabelNode(text: centerGlyph())
        center.fontName = theme.titleFont
        center.fontSize = card.isPrintedJoker ? 34 : 30
        center.fontColor = card.isPrintedJoker ? theme.jokerAccent : color
        center.horizontalAlignmentMode = .center
        center.verticalAlignmentMode = .center
        center.position = CGPoint(x: 0, y: 0)
        addChild(center)

        // Badges
        if card.rank == .two && !card.isDead2 && !card.isPrintedJoker {
            // Live wild 2 — small "★" in the top-right corner.
            addBadge(text: "★", color: theme.jokerAccent, at:
                     CGPoint(x: rect.maxX - 8, y: rect.maxY - 8))
        } else if card.isDead2 {
            addBadge(text: "†", color: UIColor(white: 0.4, alpha: 1), at:
                     CGPoint(x: rect.maxX - 8, y: rect.maxY - 8))
        }
    }

    private func addBadge(text: String, color: UIColor, at position: CGPoint) {
        let l = SKLabelNode(text: text)
        l.fontName = theme.titleFont
        l.fontSize = 12
        l.fontColor = color
        l.horizontalAlignmentMode = .center
        l.verticalAlignmentMode = .center
        l.position = position
        addChild(l)
    }

    private func addBackPattern(rect: CGRect) {
        // Simple diagonal cross-hatch panel inset from the border.
        let inset: CGFloat = 6
        let panel = SKShapeNode(
            rect: rect.insetBy(dx: inset, dy: inset),
            cornerRadius: 6
        )
        panel.fillColor = theme.cardBackAccent.withAlphaComponent(0.15)
        panel.strokeColor = theme.cardBackAccent.withAlphaComponent(0.6)
        panel.lineWidth = 1
        addChild(panel)
        let mark = SKLabelNode(text: "◆")
        mark.fontName = theme.titleFont
        mark.fontSize = 18
        mark.fontColor = theme.cardBackAccent
        mark.horizontalAlignmentMode = .center
        mark.verticalAlignmentMode = .center
        addChild(mark)
    }

    // MARK: - Card content helpers

    private func suitColor() -> UIColor {
        if card.isPrintedJoker { return theme.jokerAccent }
        switch card.suit {
        case .diamonds, .hearts: return theme.redSuit
        default: return theme.blackSuit
        }
    }

    private func glyphs() -> (String, String) {
        if card.isPrintedJoker { return ("★", "J") }
        return (rankGlyph(), suitGlyph())
    }

    private func centerGlyph() -> String {
        if card.isPrintedJoker { return "★" }
        return suitGlyph()
    }

    private func rankGlyph() -> String {
        switch card.rank {
        case .ace: return "A"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .some(let r): return "\(r.rawValue)"
        case .none: return "?"
        }
    }

    private func suitGlyph() -> String {
        switch card.suit {
        case .clubs: return "♣"
        case .diamonds: return "♦"
        case .hearts: return "♥"
        case .spades: return "♠"
        case .none: return "?"
        }
    }

    // MARK: - Static shims kept for existing call sites (unused after refactor)
    static func shortName(_ card: Card) -> String {
        if card.isPrintedJoker { return "★" }
        let s: String = {
            switch card.suit {
            case .clubs: return "♣"; case .diamonds: return "♦"
            case .hearts: return "♥"; case .spades: return "♠"
            case .none: return "?"
            }
        }()
        let r: String = {
            switch card.rank {
            case .ace: return "A"; case .jack: return "J"
            case .queen: return "Q"; case .king: return "K"
            case .some(let x): return "\(x.rawValue)"
            case .none: return "?"
            }
        }()
        return "\(r)\(s)"
    }
}
