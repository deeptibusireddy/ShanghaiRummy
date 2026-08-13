import SpriteKit

/// A single card sprite. Renders a real card face — corner rank+suit pip
/// top-left + bottom-right, a large centered suit glyph — or a themed
/// card back when `faceUp == false`. Jokers get traditional jester artwork;
/// wild 2s get a small "★" badge; dead 2s get a "†".
///
/// Colors and fonts come from the passed-in `VisualTheme` so the same
/// scene can be reskinned by swapping themes.
final class CardNode: SKNode {

    static let size = CGSize(width: 68, height: 96)

    let card: Card
    private let theme: VisualTheme
    private var faceBorder: SKShapeNode?
    private var newCardHighlight: SKNode?

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

        if card.isPrintedJoker {
            addTraditionalJokerFace(rect: rect)
            return
        }

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

        // Center glyph: large suit for quick recognition.
        let center = SKLabelNode(text: centerGlyph())
        center.fontName = theme.titleFont
        center.fontSize = 31
        center.fontColor = color
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
        } else if card.isDead2 {
            addAccentBand(rect: rect, color: UIColor(white: 0.45, alpha: 1))
            addBadge(text: "†", color: UIColor(white: 0.38, alpha: 1), at:
                     CGPoint(x: rect.maxX - 10, y: rect.maxY - 10))
        }
    }

    private func addTraditionalJokerFace(rect: CGRect) {
        let ink = theme.blackSuit
        let red = theme.redSuit

        addJokerCornerLabel(
            at: CGPoint(x: rect.minX + 5, y: rect.maxY - 6),
            rotation: 0,
            color: red
        )
        addJokerCornerLabel(
            at: CGPoint(x: rect.maxX - 5, y: rect.minY + 6),
            rotation: .pi,
            color: red
        )

        let jester = SKNode()
        jester.name = "joker-jester"
        jester.position = CGPoint(x: 0, y: 4)
        addChild(jester)

        addJesterCapLobe(
            points: [
                CGPoint(x: -8, y: 10),
                CGPoint(x: -20, y: 25),
                CGPoint(x: -13, y: 7),
            ],
            color: red,
            to: jester
        )
        addJesterCapLobe(
            points: [
                CGPoint(x: -8, y: 10),
                CGPoint(x: 0, y: 29),
                CGPoint(x: 8, y: 10),
            ],
            color: ink,
            to: jester
        )
        addJesterCapLobe(
            points: [
                CGPoint(x: 8, y: 10),
                CGPoint(x: 20, y: 25),
                CGPoint(x: 13, y: 7),
            ],
            color: red,
            to: jester
        )

        for point in [
            CGPoint(x: -20, y: 25),
            CGPoint(x: 0, y: 29),
            CGPoint(x: 20, y: 25),
        ] {
            let bell = SKShapeNode(circleOfRadius: 2.5)
            bell.fillColor = theme.jokerAccent
            bell.strokeColor = ink
            bell.lineWidth = 0.7
            bell.position = point
            jester.addChild(bell)
        }

        let face = SKShapeNode(
            rectOf: CGSize(width: 19, height: 23),
            cornerRadius: 9
        )
        face.fillColor = theme.cardFace
        face.strokeColor = ink
        face.lineWidth = 1.2
        face.position = CGPoint(x: 0, y: 0)
        jester.addChild(face)

        let capBand = SKShapeNode(
            rectOf: CGSize(width: 23, height: 5),
            cornerRadius: 2
        )
        capBand.fillColor = red
        capBand.strokeColor = ink
        capBand.lineWidth = 0.9
        capBand.position = CGPoint(x: 0, y: 10)
        jester.addChild(capBand)

        for x in [CGFloat(-4), CGFloat(4)] {
            let eye = SKShapeNode(circleOfRadius: 1.15)
            eye.fillColor = ink
            eye.strokeColor = .clear
            eye.position = CGPoint(x: x, y: 2)
            jester.addChild(eye)
        }

        let smilePath = CGMutablePath()
        smilePath.move(to: CGPoint(x: -4.5, y: -3))
        smilePath.addQuadCurve(
            to: CGPoint(x: 4.5, y: -3),
            control: CGPoint(x: 0, y: -7)
        )
        let smile = SKShapeNode(path: smilePath)
        smile.strokeColor = red
        smile.lineWidth = 1.4
        smile.lineCap = .round
        jester.addChild(smile)

        addJesterCollar(
            points: [
                CGPoint(x: -10, y: -10),
                CGPoint(x: 0, y: -23),
                CGPoint(x: 1, y: -10),
            ],
            color: red,
            to: jester
        )
        addJesterCollar(
            points: [
                CGPoint(x: -1, y: -10),
                CGPoint(x: 0, y: -23),
                CGPoint(x: 10, y: -10),
            ],
            color: ink,
            to: jester
        )

        let wordmark = SKLabelNode(text: "JOKER")
        wordmark.name = "joker-wordmark"
        wordmark.fontName = theme.titleFont
        wordmark.fontSize = 10
        wordmark.fontColor = ink
        wordmark.horizontalAlignmentMode = .center
        wordmark.verticalAlignmentMode = .center
        wordmark.position = CGPoint(x: 0, y: -34)
        addChild(wordmark)
    }

    private func addJokerCornerLabel(
        at position: CGPoint,
        rotation: CGFloat,
        color: UIColor
    ) {
        let label = SKLabelNode(text: "JOKER")
        label.fontName = theme.titleFont
        label.fontSize = 6.5
        label.fontColor = color
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .top
        label.position = position
        label.zRotation = rotation
        addChild(label)
    }

    private func addJesterCapLobe(
        points: [CGPoint],
        color: UIColor,
        to parent: SKNode
    ) {
        let lobe = SKShapeNode(path: Self.closedPath(points))
        lobe.fillColor = color
        lobe.strokeColor = theme.blackSuit
        lobe.lineWidth = 0.9
        parent.addChild(lobe)
    }

    private func addJesterCollar(
        points: [CGPoint],
        color: UIColor,
        to parent: SKNode
    ) {
        let collar = SKShapeNode(path: Self.closedPath(points))
        collar.fillColor = color
        collar.strokeColor = theme.blackSuit
        collar.lineWidth = 0.8
        parent.addChild(collar)
    }

    private static func closedPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
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

    func setNewCardHighlighted(_ highlighted: Bool) {
        newCardHighlight?.removeFromParent()
        newCardHighlight = nil
        guard highlighted else { return }

        let container = SKNode()
        container.name = "new-card-highlight"
        container.zPosition = 8

        let rect = CGRect(
            origin: CGPoint(x: -Self.size.width / 2, y: -Self.size.height / 2),
            size: Self.size
        )
        let border = SKShapeNode(rect: rect, cornerRadius: 11)
        border.fillColor = .clear
        border.strokeColor = theme.turnGlow
        border.lineWidth = 3.5
        border.glowWidth = 6
        container.addChild(border)

        let badge = SKShapeNode(
            rectOf: CGSize(width: 27, height: 14),
            cornerRadius: 7
        )
        badge.fillColor = theme.turnGlow
        badge.strokeColor = UIColor.white.withAlphaComponent(0.65)
        badge.lineWidth = 0.8
        badge.position = CGPoint(x: -16, y: -39)
        container.addChild(badge)

        let label = SKLabelNode(text: "NEW")
        label.fontName = theme.titleFont
        label.fontSize = 7
        label.fontColor = theme.blackSuit
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -0.5)
        badge.addChild(label)

        let pulse = SKAction.sequence([
            .fadeAlpha(to: 0.68, duration: 0.75),
            .fadeAlpha(to: 1.0, duration: 0.75),
        ])
        container.run(.repeatForever(pulse))
        addChild(container)
        newCardHighlight = container
    }

    func setDropTargetHighlighted(_ highlighted: Bool) {
        faceBorder?.strokeColor = highlighted ? theme.turnGlow : theme.cardStroke
        faceBorder?.lineWidth = highlighted ? 4 : 1.4
        faceBorder?.glowWidth = highlighted ? 5 : 0
    }

    // MARK: - Static shims kept for existing call sites (unused after refactor)
    static func shortName(_ card: Card) -> String {
        if card.isPrintedJoker { return "JOKER" }
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
