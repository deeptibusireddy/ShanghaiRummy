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
    private let theme: VisualTheme
    private var cancellables: Set<AnyCancellable> = []

    private let feltNode = SKShapeNode()
    private let pilesLayer = SKNode()
    private let seatsLayer = SKNode()
    private let meldsLayer = SKNode()
    private let handLayer = SKNode()
    private let bannerLabel = SKLabelNode(text: "")

    init(size: CGSize, viewModel: GameViewModel, theme: VisualTheme = .cozyWood) {
        self.vm = viewModel
        self.theme = theme
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = theme.background
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        buildStaticLayers()
        addChild(pilesLayer)
        addChild(seatsLayer)
        addChild(meldsLayer)
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
        feltNode.fillColor = theme.feltFill
        feltNode.strokeColor = theme.feltStroke
        feltNode.lineWidth = theme.feltStrokeWidth
        feltNode.zPosition = -10
        addChild(feltNode)

        bannerLabel.removeFromParent()
        bannerLabel.fontName = theme.titleFont
        bannerLabel.fontSize = 18
        bannerLabel.fontColor = theme.bannerText
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
        let name = vm.currentPlayerName
        let turnPhrase = (name == "You") ? "Your turn" : "\(name)'s turn"
        bannerLabel.text = "\(turnPhrase)  •  Level \(vm.currentPlayer.currentLevel) of \(RulesConfig.maxLevel)  •  \(vm.currentContractDescription)"
        buildPiles()
        buildSeats()
        buildMelds()
        buildHand()
    }

    private func buildPiles() {
        pilesLayer.removeAllChildren()
        let center = SeatLayout.pileCenter(sceneSize: size)
        let gap: CGFloat = 12

        // Stock (face-down top card if any).
        if let top = vm.state.stock.last {
            let stock = CardNode(card: top, faceUp: false, theme: theme)
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
            let discard = CardNode(card: top, faceUp: true, theme: theme)
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
        l.fontName = theme.bodyFont
        l.fontSize = 12
        l.fontColor = theme.pileLabel
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
            bg.fillColor = isCurrent ? theme.seatBgCurrent : theme.seatBgOther
            bg.strokeColor = theme.cardStroke
            bg.position = seat.anchor
            bg.zPosition = 2
            seatsLayer.addChild(bg)

            let title = SKLabelNode(text: (isYou ? "▸ " : "") + player.name)
            title.fontName = theme.titleFont
            title.fontSize = 13
            title.fontColor = theme.seatTitle
            title.horizontalAlignmentMode = .center
            title.verticalAlignmentMode = .center
            title.position = CGPoint(x: seat.anchor.x, y: seat.anchor.y + 8)
            title.zPosition = 3
            seatsLayer.addChild(title)

            let sub = SKLabelNode(text: "Lv \(player.currentLevel)  •  \(player.totalScore) pts")
            sub.fontName = theme.bodyFont
            sub.fontSize = 11
            sub.fontColor = theme.seatSub
            sub.horizontalAlignmentMode = .center
            sub.verticalAlignmentMode = .center
            sub.position = CGPoint(x: seat.anchor.x, y: seat.anchor.y - 8)
            sub.zPosition = 3
            seatsLayer.addChild(sub)
        }
    }

    private func buildMelds() {
        meldsLayer.removeAllChildren()
        let seats = SeatLayout.seats(
            playerCount: vm.state.players.count,
            youIndex: vm.state.currentTurnIndex,
            sceneSize: size
        )
        // Group melds by owner id for O(1) lookup per player.
        var meldsByOwner: [UUID: [Meld]] = [:]
        for m in vm.state.melds {
            meldsByOwner[m.ownerId, default: []].append(m)
        }
        for (i, player) in vm.state.players.enumerated() {
            let melds = meldsByOwner[player.id] ?? []
            guard !melds.isEmpty else { continue }
            let seat = seats[i]
            drawMelds(melds, near: seat)
        }
    }

    private func drawMelds(_ melds: [Meld], near seat: SeatLayout.Seat) {
        // Card scale: 50% of full card. Cards inside a meld overlap by 60% so
        // ranks are still visible. Melds are separated by an 18pt gap.
        let scale: CGFloat = 0.55
        let cardW = CardNode.size.width * scale
        let cardH = CardNode.size.height * scale
        let overlap: CGFloat = cardW * 0.4     // step between cards in one meld
        let meldGap: CGFloat = 14

        // Total width of all melds laid horizontally.
        let widths = melds.map { CGFloat($0.cards.count - 1) * overlap + cardW }
        let totalWidth = widths.reduce(0, +) + CGFloat(melds.count - 1) * meldGap

        // Anchor offset per seat edge — melds sit between the seat and the piles.
        let offset: CGPoint
        switch seat.edge {
        case .bottom:   offset = CGPoint(x: 0, y:  cardH / 2 + 30)
        case .top:      offset = CGPoint(x: 0, y: -(cardH / 2 + 30))
        case .left:     offset = CGPoint(x: totalWidth / 2 + 80, y: 0)
        case .right:    offset = CGPoint(x: -(totalWidth / 2 + 80), y: 0)
        case .topLeft:  offset = CGPoint(x: 20, y: -(cardH / 2 + 30))
        case .topRight: offset = CGPoint(x: -20, y: -(cardH / 2 + 30))
        }
        let rowY = seat.anchor.y + offset.y
        var x = seat.anchor.x + offset.x - totalWidth / 2

        for meld in melds {
            let count = meld.cards.count
            for (idx, card) in meld.cards.enumerated() {
                let node = CardNode(card: card, faceUp: true, theme: theme)
                node.setScale(scale)
                node.position = CGPoint(x: x + CGFloat(idx) * overlap + cardW / 2, y: rowY)
                node.zPosition = 3 + CGFloat(idx) * 0.01
                meldsLayer.addChild(node)
            }
            x += CGFloat(count - 1) * overlap + cardW + meldGap
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
            let node = CardNode(card: card, faceUp: true, theme: theme)
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
