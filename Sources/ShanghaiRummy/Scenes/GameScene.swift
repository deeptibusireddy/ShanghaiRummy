import SpriteKit
import Combine

/// SpriteKit scaffold scene for M2b.
///
/// Renders the fixed real-table layout described in docs/ux.md:
/// - Warm wood felt background
/// - Stock & discard piles centered
/// - One seat per player around the edges (via `SeatLayout`)
/// - The current player's hand fanned along the bottom
///
/// M2b keeps interactions simple: tap the stock to draw, tap the discard
/// to draw from discard, tap a card in your hand to discard it. Drag &
/// drop / staging tray / go-down UI arrives in M2d.
///
/// The scene observes `GameViewModel.state` via a Combine subscription and
/// rebuilds its dynamic layers whenever the state changes. Static layers
/// (felt background) are set up once in `didMove(to:)`.
final class GameScene: SKScene {

    private let vm: GameViewModel
    private var cancellables: Set<AnyCancellable> = []

    private let feltNode = SKShapeNode()
    private let pilesLayer = SKNode()
    private let seatsLayer = SKNode()
    private let handLayer = SKNode()
    private let bannerLabel = SKLabelNode(text: "")

    init(size: CGSize, viewModel: GameViewModel) {
        self.vm = viewModel
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.32, green: 0.22, blue: 0.14, alpha: 1) // dark walnut
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        buildStaticLayers()
        addChild(pilesLayer)
        addChild(seatsLayer)
        addChild(handLayer)
        rebuildDynamicLayers()
        subscribeToViewModel()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        buildStaticLayers()
        rebuildDynamicLayers()
    }

    // MARK: - Static layers (felt, banner)

    private func buildStaticLayers() {
        feltNode.removeFromParent()
        let inset: CGFloat = 12
        let rect = CGRect(origin: CGPoint(x: inset, y: inset),
                          size: CGSize(width: size.width - 2 * inset,
                                       height: size.height - 2 * inset))
        feltNode.path = CGPath(roundedRect: rect,
                               cornerWidth: 20, cornerHeight: 20,
                               transform: nil)
        feltNode.fillColor = UIColor(red: 0.44, green: 0.32, blue: 0.22, alpha: 1) // warm wood
        feltNode.strokeColor = UIColor(red: 0.85, green: 0.72, blue: 0.52, alpha: 0.6) // warm-gold rim
        feltNode.lineWidth = 3
        feltNode.zPosition = -10
        addChild(feltNode)

        bannerLabel.removeFromParent()
        bannerLabel.fontName = "HelveticaNeue-Bold"
        bannerLabel.fontSize = 18
        bannerLabel.fontColor = UIColor(white: 0.98, alpha: 1)
        bannerLabel.horizontalAlignmentMode = .center
        bannerLabel.verticalAlignmentMode = .top
        bannerLabel.position = CGPoint(x: size.width / 2, y: size.height - 20)
        bannerLabel.zPosition = 5
        addChild(bannerLabel)
    }

    // MARK: - Dynamic layers (rebuild on state change)

    private func subscribeToViewModel() {
        vm.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildDynamicLayers() }
            .store(in: &cancellables)
    }

    private func rebuildDynamicLayers() {
        bannerLabel.text = "\(vm.currentPlayerName)'s turn  •  Level \(vm.currentPlayer.currentLevel) of \(RulesConfig.maxLevel)  •  \(vm.currentContractDescription)"
        buildPiles()
        buildSeats()
        buildHand()
    }

    private func buildPiles() {
        pilesLayer.removeAllChildren()
        let center = SeatLayout.pileCenter(sceneSize: size)
        let gap: CGFloat = 12

        // Stock (face-down top card if any).
        if let top = vm.state.stock.last {
            let stock = CardNode(card: top, faceUp: false)
            stock.position = CGPoint(x: center.x - CardNode.size.width / 2 - gap / 2,
                                     y: center.y)
            stock.name = "stock"
            pilesLayer.addChild(stock)
        }
        stockLabel(at: CGPoint(x: center.x - CardNode.size.width / 2 - gap / 2,
                               y: center.y - CardNode.size.height / 2 - 14),
                   text: "Stock  \(vm.state.stock.count)")

        // Discard (top face-up card).
        if let top = vm.state.discard.last {
            let discard = CardNode(card: top, faceUp: true)
            discard.position = CGPoint(x: center.x + CardNode.size.width / 2 + gap / 2,
                                       y: center.y)
            discard.name = "discard"
            pilesLayer.addChild(discard)
        }
        stockLabel(at: CGPoint(x: center.x + CardNode.size.width / 2 + gap / 2,
                               y: center.y - CardNode.size.height / 2 - 14),
                   text: "Discard  \(vm.state.discard.count)")
    }

    private func stockLabel(at position: CGPoint, text: String) {
        let l = SKLabelNode(text: text)
        l.fontName = "HelveticaNeue"
        l.fontSize = 12
        l.fontColor = UIColor(white: 0.92, alpha: 0.9)
        l.horizontalAlignmentMode = .center
        l.verticalAlignmentMode = .top
        l.position = position
        pilesLayer.addChild(l)
    }

    private func buildSeats() {
        seatsLayer.removeAllChildren()
        let seats = SeatLayout.seats(
            playerCount: vm.state.players.count,
            youIndex: vm.state.currentTurnIndex,
            sceneSize: size
        )
        for (i, player) in vm.state.players.enumerated() {
            let seat = seats[i]
            let isCurrent = player.id == vm.currentPlayer.id
            let isYou = i == vm.state.currentTurnIndex

            let bgWidth: CGFloat = 140
            let bgHeight: CGFloat = 44
            let bg = SKShapeNode(rectOf: CGSize(width: bgWidth, height: bgHeight),
                                 cornerRadius: 8)
            bg.fillColor = isCurrent
                ? UIColor(red: 0.85, green: 0.72, blue: 0.52, alpha: 0.9)
                : UIColor(white: 0.98, alpha: 0.85)
            bg.strokeColor = UIColor(white: 0.15, alpha: 0.3)
            bg.position = seat.anchor
            bg.zPosition = 2
            seatsLayer.addChild(bg)

            let title = SKLabelNode(text: (isYou ? "▸ " : "") + player.name)
            title.fontName = "HelveticaNeue-Bold"
            title.fontSize = 13
            title.fontColor = UIColor(white: 0.10, alpha: 1)
            title.horizontalAlignmentMode = .center
            title.verticalAlignmentMode = .center
            title.position = CGPoint(x: seat.anchor.x, y: seat.anchor.y + 8)
            title.zPosition = 3
            seatsLayer.addChild(title)

            let sub = SKLabelNode(text: "Lv \(player.currentLevel)  •  \(player.totalScore) pts")
            sub.fontName = "HelveticaNeue"
            sub.fontSize = 11
            sub.fontColor = UIColor(white: 0.25, alpha: 1)
            sub.horizontalAlignmentMode = .center
            sub.verticalAlignmentMode = .center
            sub.position = CGPoint(x: seat.anchor.x, y: seat.anchor.y - 8)
            sub.zPosition = 3
            seatsLayer.addChild(sub)
        }
    }

    private func buildHand() {
        handLayer.removeAllChildren()
        // Only the current player's hand is shown (hot-seat privacy).
        let hand = vm.currentPlayer.hand
        guard !hand.isEmpty else { return }

        let cardWidth = CardNode.size.width
        let spacing: CGFloat = 8
        let totalWidth = CGFloat(hand.count) * cardWidth + CGFloat(hand.count - 1) * spacing
        var x = (size.width - totalWidth) / 2 + cardWidth / 2
        let y: CGFloat = 68

        for card in hand {
            let node = CardNode(card: card, faceUp: true)
            node.position = CGPoint(x: x, y: y)
            node.zPosition = 4
            handLayer.addChild(node)
            x += cardWidth + spacing
        }
    }

    // MARK: - Input

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        // Nearest tapped node with a name we recognize.
        for node in nodes(at: point) {
            if node.name == "stock" || node.parent?.name == "stock" {
                vm.drawFromStock()
                return
            }
            if node.name == "discard" || node.parent?.name == "discard" {
                vm.drawFromDiscard()
                return
            }
            if let cardName = node.name, cardName.hasPrefix("card:"),
               let cardIdString = cardName.split(separator: ":").last,
               let uuid = UUID(uuidString: String(cardIdString)),
               let card = vm.currentPlayer.hand.first(where: { $0.id == uuid }) {
                // For M2b, tapping a hand card = discard it (same behaviour as
                // the SwiftUI placeholder). Drag-to-discard arrives in M2d.
                vm.discard(card)
                return
            }
        }
    }
}
