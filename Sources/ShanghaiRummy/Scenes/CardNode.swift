import SpriteKit

/// A single card sprite for the placeholder scene.
///
/// M2b uses text-labeled rounded rectangles. Real card art (rank/suit corner
/// pips, face cards, joker illustration) lands in M2c.
final class CardNode: SKNode {

    static let size = CGSize(width: 60, height: 84)

    let card: Card
    private let background: SKShapeNode
    private let label: SKLabelNode

    init(card: Card, faceUp: Bool = true) {
        self.card = card
        let rect = CGRect(origin: CGPoint(x: -Self.size.width / 2,
                                          y: -Self.size.height / 2),
                          size: Self.size)
        background = SKShapeNode(rect: rect, cornerRadius: 8)
        label = SKLabelNode(text: "")
        super.init()

        background.fillColor = faceUp ? UIColor(white: 0.98, alpha: 1) : UIColor(red: 0.90, green: 0.83, blue: 0.72, alpha: 1)
        background.strokeColor = UIColor(white: 0.25, alpha: 0.4)
        background.lineWidth = 1
        addChild(background)

        label.fontName = "HelveticaNeue-Bold"
        label.fontSize = 18
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.fontColor = Self.color(for: card)
        label.text = faceUp ? Self.shortName(card) : ""
        addChild(label)

        isUserInteractionEnabled = false // Scene handles taps globally.
        name = "card:\(card.id.uuidString)"
    }

    required init?(coder: NSCoder) { fatalError() }

    static func shortName(_ card: Card) -> String {
        if card.isPrintedJoker { return "🃏" }
        let suit: String = {
            switch card.suit {
            case .clubs: return "♣"
            case .diamonds: return "♦"
            case .hearts: return "♥"
            case .spades: return "♠"
            case .none: return "?"
            }
        }()
        let rank: String = {
            switch card.rank {
            case .ace: return "A"
            case .jack: return "J"
            case .queen: return "Q"
            case .king: return "K"
            case .some(let r): return "\(r.rawValue)"
            case .none: return "?"
            }
        }()
        let dead = card.isDead2 ? "†" : ""
        return "\(rank)\(suit)\(dead)"
    }

    static func color(for card: Card) -> UIColor {
        if card.isPrintedJoker { return UIColor.purple }
        switch card.suit {
        case .diamonds, .hearts: return UIColor(red: 0.75, green: 0.20, blue: 0.15, alpha: 1)
        default: return UIColor(white: 0.15, alpha: 1)
        }
    }
}
