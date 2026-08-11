import SpriteKit

/// A single card sprite. Renders a real card face — corner rank+suit pip
/// top-left + bottom-right, a large centered suit glyph — or a themed
/// card back when `faceUp == false`. Jokers get a star; wild 2s get a
/// small "★" badge; dead 2s get a "†".
///
/// Colors and fonts come from the passed-in `VisualTheme` so the same
/// scene can be reskinned by swapping themes.
final class CardNode: SKNode {

    static let size = CGSize(width: 68, height: 96)

    let card: Card
    private let theme: VisualTheme
    private var faceBorder: SKShapeNode?

    init(card: Card, faceUp: Bool = true, theme: VisualTheme = .gameNight) {
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
        let bg = SKShapeNode(rect: rect, cornerRadius: 11)
        bg.strokeColor = theme.cardStroke
        bg.lineWidth = 1.4
        addChild(bg)
        faceBorder = bg

        if !faceUp {
            bg.fillColor = theme.cardBack
            addBackPattern(rect: rect)
            return
        }

        bg.fillColor = theme.cardFace
        let inner = SKShapeNode(rect: rect.insetBy(dx: 2.5, dy: 2.5),
                                cornerRadius: 9)
        inner.fillColor = .clear
        inner.strokeColor = UIColor.white.withAlphaComponent(0.42)
        inner.lineWidth = 0.8
        addChild(inner)

        let color = suitColor()
        let (rank, suit) = glyphs()

        // Large, high-contrast corner index remains readable when a big hand
        // compresses into an overlapping fan.
        let cornerRank = SKLabelNode(text: rank)
        cornerRank.fontName = theme.titleFont
        cornerRank.fontSize = 17
        cornerRank.fontColor = color
        cornerRank.horizontalAlignmentMode = .left
        cornerRank.verticalAlignmentMode = .top
        cornerRank.position = CGPoint(x: rect.minX + 6, y: rect.maxY - 5)
        addChild(cornerRank)

        let cornerSuit = SKLabelNode(text: suit)
        cornerSuit.fontName = theme.bodyFont
        cornerSuit.fontSize = 13
        cornerSuit.fontColor = color
        cornerSuit.horizontalAlignmentMode = .left
        cornerSuit.verticalAlignmentMode = .top
        cornerSuit.position = CGPoint(x: rect.minX + 6, y: rect.maxY - 24)
        addChild(cornerSuit)

        // Bottom-right corner pip: rotated 180°.
        let brContainer = SKNode()
        brContainer.zRotation = .pi
        brContainer.position = CGPoint(x: rect.maxX - 6, y: rect.minY + 5)
        let brRank = SKLabelNode(text: rank)
        brRank.fontName = theme.titleFont
        brRank.fontSize = 13
        brRank.fontColor = color
        brRank.horizontalAlignmentMode = .left
        brRank.verticalAlignmentMode = .top
        brContainer.addChild(brRank)
        let brSuit = SKLabelNode(text: suit)
        brSuit.fontName = theme.bodyFont
        brSuit.fontSize = 10
        brSuit.fontColor = color
        brSuit.horizontalAlignmentMode = .left
        brSuit.verticalAlignmentMode = .top
        brSuit.position = CGPoint(x: 0, y: -15)
        brContainer.addChild(brSuit)
        addChild(brContainer)

        // Center glyph: big suit (or a star for the joker).
        let center = SKLabelNode(text: centerGlyph())
        center.fontName = theme.titleFont
        center.fontSize = card.isPrintedJoker ? 36 : 31
        center.fontColor = card.isPrintedJoker ? theme.jokerAccent : color
        center.horizontalAlignmentMode = .center
        center.verticalAlignmentMode = .center
        center.position = CGPoint(x: 0, y: 0)
        addChild(center)

        // Wild cards get an unmistakable accent treatment; tiny badges alone
        // disappear in compressed hands and are easy to miss on a phone.
        if card.rank == .two && !card.isDead2 && !card.isPrintedJoker {
            addAccentBand(rect: rect, color: theme.jokerAccent)
            addBadge(text: "W", color: theme.jokerAccent, at:
                     CGPoint(x: rect.maxX - 10, y: rect.maxY - 10))
        } else if card.isPrintedJoker {
            addAccentBand(rect: rect, color: theme.jokerAccent)
        } else if card.isDead2 {
            addAccentBand(rect: rect, color: UIColor(white: 0.45, alpha: 1))
            addBadge(text: "†", color: UIColor(white: 0.38, alpha: 1), at:
                     CGPoint(x: rect.maxX - 10, y: rect.maxY - 10))
        }
    }

    private func addAccentBand(rect: CGRect, color: UIColor) {
        let band = SKShapeNode(
            rect: CGRect(x: rect.maxX - 5, y: rect.minY + 10,
                         width: 3, height: rect.height - 20),
            cornerRadius: 1.5
        )
        band.fillColor = color
        band.strokeColor = .clear
        addChild(band)
    }

    private func addBadge(text: String, color: UIColor, at position: CGPoint) {
        let l = SKLabelNode(text: text)
        l.fontName = theme.titleFont
        l.fontSize = 11
        l.fontColor = color
        l.horizontalAlignmentMode = .center
        l.verticalAlignmentMode = .center
        l.position = position
        addChild(l)
    }

    private func addBackPattern(rect: CGRect) {
        let inset: CGFloat = 7
        let panel = SKShapeNode(
            rect: rect.insetBy(dx: inset, dy: inset),
            cornerRadius: 7
        )
        panel.fillColor = theme.cardBackAccent.withAlphaComponent(0.08)
        panel.strokeColor = theme.cardBackAccent.withAlphaComponent(0.72)
        panel.lineWidth = 1.2
        addChild(panel)
        let inner = SKShapeNode(
            rect: rect.insetBy(dx: inset + 4, dy: inset + 4),
            cornerRadius: 5
        )
        inner.fillColor = .clear
        inner.strokeColor = theme.cardBackAccent.withAlphaComponent(0.28)
        inner.lineWidth = 1
        addChild(inner)
        let mark = SKLabelNode(text: "✦")
        mark.fontName = theme.titleFont
        mark.fontSize = 24
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

    func showWildRepresentation(_ representation: MeldValidator.WildRepresentation) {
        guard card.isWild else { return }

        let pill = SKShapeNode(rectOf: CGSize(width: 48, height: 20), cornerRadius: 8)
        pill.fillColor = theme.cardFace.withAlphaComponent(0.96)
        pill.strokeColor = theme.jokerAccent
        pill.lineWidth = 1.5
        pill.position = CGPoint(x: 0, y: -22)
        pill.zPosition = 5
        addChild(pill)

        let label = SKLabelNode(
            text: Self.shortName(rank: representation.rank, suit: representation.suit)
        )
        label.fontName = theme.titleFont
        label.fontSize = 13
        label.fontColor = representation.suit == .hearts
            || representation.suit == .diamonds
            ? theme.redSuit
            : theme.blackSuit
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -0.5)
        pill.addChild(label)
    }

    func setDropTargetHighlighted(_ highlighted: Bool) {
        faceBorder?.strokeColor = highlighted ? theme.turnGlow : theme.cardStroke
        faceBorder?.lineWidth = highlighted ? 4 : 1.4
        faceBorder?.glowWidth = highlighted ? 5 : 0
    }

    // MARK: - Static shims kept for existing call sites (unused after refactor)
    static func shortName(_ card: Card) -> String {
        if card.isPrintedJoker { return "★" }
        guard let rank = card.rank, let suit = card.suit else { return "?" }
        return shortName(rank: rank, suit: suit)
    }

    static func shortName(rank: Rank, suit: Suit) -> String {
        let rankText: String
        switch rank {
        case .ace: rankText = "A"
        case .jack: rankText = "J"
        case .queen: rankText = "Q"
        case .king: rankText = "K"
        default: rankText = "\(rank.rawValue)"
        }

        let suitText: String
        switch suit {
        case .clubs: suitText = "♣"
        case .diamonds: suitText = "♦"
        case .hearts: suitText = "♥"
        case .spades: suitText = "♠"
        }
        return "\(rankText)\(suitText)"
    }
}
