import SpriteKit
import Combine

/// SpriteKit scene rendering the whole table.
///
/// Layout (all themes):
///   • Felt fills the screen with a warm-gold rim.
///   • Soft radial spotlight + faint "SR" monogram behind the piles for depth.
///   • Stock (face-down) + discard (top-3 fan) centered above midline.
///   • One seat per player around the edges (via SeatLayout).
///     Each seat: avatar circle with initial, name row, level + score chip.
///     Current seat gets a pulsing gold halo.
///   • Contract pill sits below the banner text at the top edge.
///   • The current player's hand fans slightly along the bottom.
///
/// The scene observes GameViewModel.state via a Combine subscription and
/// rebuilds dynamic layers on every change. Static layers (felt, glow,
/// emblem) are built once in didMove(to:) and didChangeSize(_:).
final class GameScene: SKScene {

    private let vm: GameViewModel
    private let theme: VisualTheme
    private var cancellables: Set<AnyCancellable> = []

    private let feltNode = SKShapeNode()
    private let glowNode = SKShapeNode()
    private let emblemNode = SKLabelNode(text: "")
    private let shadowsLayer = SKNode()
    private let pilesLayer = SKNode()
    private let seatsLayer = SKNode()
    private let meldsLayer = SKNode()
    private let handLayer = SKNode()
    private let bannerLabel = SKLabelNode(text: "")
    private let contractPill = SKNode()

    // Drag-and-drop state (M2d-a).
    private var draggingCard: CardNode?
    private var dragOrigin: CGPoint = .zero
    private var dragOriginRotation: CGFloat = 0
    private var dragOriginZ: CGFloat = 0
    private var draggingCardId: UUID?
    private var discardTargetRing: SKShapeNode?

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
        addChild(shadowsLayer)
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

    // MARK: - Static layers (felt, glow, emblem, banner)

    private func buildStaticLayers() {
        feltNode.removeFromParent()
        glowNode.removeFromParent()
        emblemNode.removeFromParent()
        bannerLabel.removeFromParent()
        contractPill.removeAllChildren()
        contractPill.removeFromParent()

        // Felt with rounded corners + wide rim.
        let inset: CGFloat = 12
        let rect = CGRect(origin: CGPoint(x: inset, y: inset),
                          size: CGSize(width: size.width - 2 * inset,
                                       height: size.height - 2 * inset))
        feltNode.path = CGPath(roundedRect: rect,
                               cornerWidth: 22, cornerHeight: 22,
                               transform: nil)
        feltNode.fillColor = theme.feltFill
        feltNode.strokeColor = theme.feltStroke
        feltNode.lineWidth = theme.feltStrokeWidth
        feltNode.zPosition = -10
        addChild(feltNode)

        // Soft radial spotlight behind piles.
        let center = SeatLayout.pileCenter(sceneSize: size)
        let glowSize: CGFloat = min(size.width, size.height) * 0.85
        glowNode.path = CGPath(ellipseIn: CGRect(x: -glowSize / 2, y: -glowSize / 2,
                                                 width: glowSize, height: glowSize),
                               transform: nil)
        glowNode.fillColor = theme.feltGlow.withAlphaComponent(0.20)
        glowNode.strokeColor = .clear
        glowNode.position = center
        glowNode.zPosition = -9
        glowNode.blendMode = .add
        addChild(glowNode)

        // Faint center monogram behind piles.
        emblemNode.text = "SR"
        emblemNode.fontName = theme.titleFont
        emblemNode.fontSize = 96
        emblemNode.fontColor = theme.emblemColor
        emblemNode.horizontalAlignmentMode = .center
        emblemNode.verticalAlignmentMode = .center
        emblemNode.position = center
        emblemNode.zPosition = -8
        addChild(emblemNode)

        // Banner
        bannerLabel.fontName = theme.titleFont
        bannerLabel.fontSize = 20
        bannerLabel.fontColor = theme.bannerText
        bannerLabel.horizontalAlignmentMode = .center
        bannerLabel.verticalAlignmentMode = .top
        bannerLabel.position = CGPoint(x: size.width / 2, y: size.height - 16)
        bannerLabel.zPosition = 5
        addChild(bannerLabel)

        contractPill.zPosition = 5
        addChild(contractPill)
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
        bannerLabel.text = turnPhrase
        shadowsLayer.removeAllChildren()
        buildContractPill()
        buildPiles()
        buildSeats()
        buildMelds()
        buildHand()
    }

    private func buildContractPill() {
        contractPill.removeAllChildren()
        let text = "Level \(vm.currentPlayer.currentLevel) of \(RulesConfig.maxLevel)  •  \(vm.currentContractDescription)"
        let label = SKLabelNode(text: text)
        label.fontName = theme.bodyFont
        label.fontSize = 12
        label.fontColor = theme.contractPillText
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        contractPill.addChild(label)

        // Size the pill background from a rough text width estimate.
        let padX: CGFloat = 14
        let padY: CGFloat = 4
        let estWidth = CGFloat(text.count) * 6.5 + padX * 2
        let bg = SKShapeNode(rectOf: CGSize(width: estWidth, height: 22),
                             cornerRadius: 11)
        bg.fillColor = theme.contractPillBg
        bg.strokeColor = theme.turnGlow.withAlphaComponent(0.7)
        bg.lineWidth = 1
        contractPill.insertChild(bg, at: 0)
        _ = padY // silence unused warning if compiler complains

        contractPill.position = CGPoint(x: size.width / 2, y: size.height - 46)
    }

    private func buildPiles() {
        pilesLayer.removeAllChildren()
        let center = SeatLayout.pileCenter(sceneSize: size)
        let gap: CGFloat = 14

        // Stock (face-down) with a subtle stack effect.
        if let top = vm.state.stock.last {
            let stockPos = CGPoint(x: center.x - CardNode.size.width / 2 - gap / 2,
                                   y: center.y)
            // Under-card for depth.
            if vm.state.stock.count > 1 {
                let under = CardNode(card: top, faceUp: false, theme: theme)
                under.position = CGPoint(x: stockPos.x + 2, y: stockPos.y - 2)
                under.zPosition = 3
                pilesLayer.addChild(under)
            }
            let stock = CardNode(card: top, faceUp: false, theme: theme)
            attachShadow(to: stock, at: stockPos)
            stock.position = stockPos
            stock.zPosition = 4
            stock.name = "stock"
            pilesLayer.addChild(stock)
            addPileLabel(at: CGPoint(x: stockPos.x, y: stockPos.y - CardNode.size.height / 2 - 14),
                         text: "Stock  \(vm.state.stock.count)")
        }

        // Discard: show top 3 cards fanned so history is visible.
        if !vm.state.discard.isEmpty {
            let basePos = CGPoint(x: center.x + CardNode.size.width / 2 + gap / 2,
                                  y: center.y)
            let recent = Array(vm.state.discard.suffix(3))
            for (i, card) in recent.enumerated() {
                let isTop = (i == recent.count - 1)
                let stackIdx = recent.count - 1 - i    // 2 (bottom) ... 0 (top)
                let offset = CGFloat(stackIdx) * 4
                let rotation = CGFloat(stackIdx) * -0.04
                let pos = CGPoint(x: basePos.x - offset, y: basePos.y + offset)
                let node = CardNode(card: card, faceUp: true, theme: theme)
                node.position = pos
                node.zRotation = rotation
                node.zPosition = 4 + CGFloat(i)
                if isTop {
                    attachShadow(to: node, at: pos, rotation: rotation)
                    node.name = "discard"
                }
                pilesLayer.addChild(node)
            }
            addPileLabel(at: CGPoint(x: basePos.x, y: basePos.y - CardNode.size.height / 2 - 14),
                         text: "Discard  \(vm.state.discard.count)")
        }
    }

    private func addPileLabel(at position: CGPoint, text: String) {
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

            let bgWidth: CGFloat = 158
            let bgHeight: CGFloat = 52

            // Turn glow halo behind current player's seat.
            if isCurrent {
                let halo = SKShapeNode(
                    rectOf: CGSize(width: bgWidth + 14, height: bgHeight + 14),
                    cornerRadius: 14)
                halo.fillColor = theme.turnGlow.withAlphaComponent(0.40)
                halo.strokeColor = theme.turnGlow
                halo.lineWidth = 2
                halo.glowWidth = 8
                halo.position = seat.anchor
                halo.zPosition = 1
                seatsLayer.addChild(halo)
            }

            let bg = SKShapeNode(rectOf: CGSize(width: bgWidth, height: bgHeight),
                                 cornerRadius: 10)
            bg.fillColor = isCurrent ? theme.seatBgCurrent : theme.seatBgOther
            bg.strokeColor = theme.cardStroke
            bg.position = seat.anchor
            bg.zPosition = 2
            seatsLayer.addChild(bg)

            // Avatar circle on the left side of the seat.
            let avatarColor = theme.avatarColors[i % theme.avatarColors.count]
            let avatarRadius: CGFloat = 16
            let avatarX = seat.anchor.x - bgWidth / 2 + avatarRadius + 6
            let avatar = SKShapeNode(circleOfRadius: avatarRadius)
            avatar.fillColor = avatarColor
            avatar.strokeColor = UIColor(white: 1.0, alpha: 0.9)
            avatar.lineWidth = 1.5
            avatar.position = CGPoint(x: avatarX, y: seat.anchor.y)
            avatar.zPosition = 3
            seatsLayer.addChild(avatar)
            let initial = SKLabelNode(text: String(player.name.prefix(1)).uppercased())
            initial.fontName = theme.titleFont
            initial.fontSize = 16
            initial.fontColor = UIColor.white
            initial.horizontalAlignmentMode = .center
            initial.verticalAlignmentMode = .center
            initial.position = CGPoint(x: avatarX, y: seat.anchor.y)
            initial.zPosition = 4
            seatsLayer.addChild(initial)

            // Name text right of the avatar.
            let nameX = avatarX + avatarRadius + 8
            let title = SKLabelNode(text: (isYou ? "▸ " : "") + player.name)
            title.fontName = theme.titleFont
            title.fontSize = 14
            title.fontColor = theme.seatTitle
            title.horizontalAlignmentMode = .left
            title.verticalAlignmentMode = .center
            title.position = CGPoint(x: nameX, y: seat.anchor.y + 8)
            title.zPosition = 3
            seatsLayer.addChild(title)

            // Level + score as a chip.
            let chipText = "Lv \(player.currentLevel)  •  \(player.totalScore) pts"
            let chipLabel = SKLabelNode(text: chipText)
            chipLabel.fontName = theme.bodyFont
            chipLabel.fontSize = 11
            chipLabel.fontColor = theme.scoreChipText
            chipLabel.horizontalAlignmentMode = .center
            chipLabel.verticalAlignmentMode = .center
            let chipWidth = CGFloat(chipText.count) * 5.6 + 12
            let chip = SKShapeNode(rectOf: CGSize(width: chipWidth, height: 16),
                                   cornerRadius: 8)
            chip.fillColor = theme.scoreChipBg
            chip.strokeColor = .clear
            chip.position = CGPoint(x: nameX + chipWidth / 2, y: seat.anchor.y - 9)
            chip.zPosition = 3
            seatsLayer.addChild(chip)
            chipLabel.position = chip.position
            chipLabel.zPosition = 4
            seatsLayer.addChild(chipLabel)
        }
    }

    private func buildMelds() {
        meldsLayer.removeAllChildren()
        let seats = SeatLayout.seats(
            playerCount: vm.state.players.count,
            youIndex: vm.state.currentTurnIndex,
            sceneSize: size
        )
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
        let scale: CGFloat = 0.58
        let cardW = CardNode.size.width * scale
        let cardH = CardNode.size.height * scale
        let overlap: CGFloat = cardW * 0.42
        let meldGap: CGFloat = 16

        let widths = melds.map { CGFloat($0.cards.count - 1) * overlap + cardW }
        let totalWidth = widths.reduce(0, +) + CGFloat(melds.count - 1) * meldGap

        let offset: CGPoint
        switch seat.edge {
        case .bottom:   offset = CGPoint(x: 0, y:  cardH / 2 + 34)
        case .top:      offset = CGPoint(x: 0, y: -(cardH / 2 + 34))
        case .left:     offset = CGPoint(x: totalWidth / 2 + 88, y: 0)
        case .right:    offset = CGPoint(x: -(totalWidth / 2 + 88), y: 0)
        case .topLeft:  offset = CGPoint(x: 24, y: -(cardH / 2 + 34))
        case .topRight: offset = CGPoint(x: -24, y: -(cardH / 2 + 34))
        }
        let rowY = seat.anchor.y + offset.y
        var x = seat.anchor.x + offset.x - totalWidth / 2

        for meld in melds {
            let count = meld.cards.count
            for (idx, card) in meld.cards.enumerated() {
                let node = CardNode(card: card, faceUp: true, theme: theme)
                node.setScale(scale)
                let pos = CGPoint(x: x + CGFloat(idx) * overlap + cardW / 2, y: rowY)
                if idx == 0 { attachShadow(to: node, at: pos, scale: scale) }
                node.position = pos
                node.zPosition = 3 + CGFloat(idx) * 0.01
                meldsLayer.addChild(node)
            }
            x += CGFloat(count - 1) * overlap + cardW + meldGap
        }
    }

    private func buildHand() {
        handLayer.removeAllChildren()
        let hand = vm.currentPlayer.hand
        guard !hand.isEmpty else { return }

        let cardWidth = CardNode.size.width
        let spacing: CGFloat = 8
        let totalWidth = CGFloat(hand.count) * cardWidth + CGFloat(hand.count - 1) * spacing
        let startX = (size.width - totalWidth) / 2 + cardWidth / 2
        let baseY: CGFloat = 74
        // Slight arc: middle cards raised, edges lowered. Fan rotation ±3°.
        let maxLift: CGFloat = 6
        let maxAngle: CGFloat = 0.05  // radians (~2.9°)

        for (i, card) in hand.enumerated() {
            let node = CardNode(card: card, faceUp: true, theme: theme)
            node.name = "card:\(card.id.uuidString)"
            let centeredIdx = CGFloat(i) - CGFloat(hand.count - 1) / 2
            let norm = centeredIdx / max(1, CGFloat(hand.count - 1) / 2) // -1...1
            let lift = maxLift * (1 - norm * norm) // parabolic
            let x = startX + CGFloat(i) * (cardWidth + spacing)
            let y = baseY + lift
            let angle = -norm * maxAngle
            let pos = CGPoint(x: x, y: y)
            attachShadow(to: node, at: pos, rotation: angle)
            node.position = pos
            node.zRotation = angle
            node.zPosition = 4 + CGFloat(i) * 0.01
            handLayer.addChild(node)
        }
    }

    // MARK: - Helpers

    /// Adds a drop-shadow shape to the shadows layer, sized to match `card`.
    /// The shadows layer is cleared on every dynamic rebuild.
    private func attachShadow(
        to card: CardNode,
        at position: CGPoint,
        rotation: CGFloat = 0,
        scale: CGFloat = 1.0
    ) {
        let rect = CGRect(
            x: -CardNode.size.width / 2 * scale,
            y: -CardNode.size.height / 2 * scale,
            width: CardNode.size.width * scale,
            height: CardNode.size.height * scale
        )
        let shadow = SKShapeNode(rect: rect, cornerRadius: 8 * scale)
        shadow.fillColor = theme.cardShadow
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: position.x + 2, y: position.y - 3)
        shadow.zRotation = rotation
        shadow.zPosition = card.zPosition - 0.5
        shadowsLayer.addChild(shadow)
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        // Pile taps come first (they don't start drags).
        for node in nodes(at: point) {
            if node.name == "stock" || node.parent?.name == "stock" {
                vm.drawFromStock()
                return
            }
        }

        // Try to begin a hand-card drag. Only the current player can drag.
        for node in nodes(at: point) {
            var target: SKNode? = node
            while let t = target, !(t.name?.hasPrefix("card:") ?? false) {
                target = t.parent
            }
            guard let hit = target as? CardNode,
                  let name = hit.name,
                  let idStr = name.split(separator: ":").last,
                  let uuid = UUID(uuidString: String(idStr)),
                  vm.currentPlayer.hand.contains(where: { $0.id == uuid })
            else { continue }
            beginDrag(card: hit, id: uuid)
            return
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let card = draggingCard else { return }
        card.position = touch.location(in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            cancelDrag()
            return
        }
        let point = touch.location(in: self)

        if draggingCard == nil {
            // No drag in progress → treat as a tap. Currently the only
            // remaining tap target is the discard pile (for drawFromDiscard);
            // hand-card discards are drag-only now.
            for node in nodes(at: point) {
                if node.name == "discard" || node.parent?.name == "discard" {
                    vm.drawFromDiscard()
                    return
                }
            }
            return
        }

        // Resolve drag drop.
        if discardDropZone().contains(point),
           let id = draggingCardId,
           let card = vm.currentPlayer.hand.first(where: { $0.id == id }) {
            // Attempt discard. If engine rejects (e.g., wrong phase), snap back.
            let ok = vm.dispatch(.discard(playerId: vm.currentPlayer.id, card: card))
            if ok {
                // Successful discard triggers a rebuild via publisher; clear
                // drag bookkeeping here.
                draggingCard = nil
                draggingCardId = nil
                clearDiscardTarget()
                return
            }
            // Fell through: snap back.
        }

        cancelDrag()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelDrag()
    }

    // MARK: - Drag helpers

    private func beginDrag(card: CardNode, id: UUID) {
        draggingCard = card
        draggingCardId = id
        dragOrigin = card.position
        dragOriginRotation = card.zRotation
        dragOriginZ = card.zPosition
        card.removeAllActions()
        card.zPosition = 500
        card.zRotation = 0
        card.run(SKAction.scale(to: 1.08, duration: 0.08))
        highlightDiscardTarget()
    }

    private func cancelDrag() {
        guard let card = draggingCard else {
            clearDiscardTarget()
            return
        }
        let snap = SKAction.group([
            SKAction.move(to: dragOrigin, duration: 0.15),
            SKAction.rotate(toAngle: dragOriginRotation, duration: 0.15,
                            shortestUnitArc: true),
            SKAction.scale(to: 1.0, duration: 0.15)
        ])
        card.run(snap) { [weak self, weak card] in
            card?.zPosition = self?.dragOriginZ ?? 4
        }
        draggingCard = nil
        draggingCardId = nil
        clearDiscardTarget()
    }

    /// The tappable/droppable rectangle around the discard pile, in scene
    /// coordinates. Slightly larger than the pile visual for easier drops.
    private func discardDropZone() -> CGRect {
        let center = SeatLayout.pileCenter(sceneSize: size)
        let gap: CGFloat = 14
        let basePos = CGPoint(x: center.x + CardNode.size.width / 2 + gap / 2,
                              y: center.y)
        let pad: CGFloat = 24
        return CGRect(
            x: basePos.x - CardNode.size.width / 2 - pad,
            y: basePos.y - CardNode.size.height / 2 - pad,
            width: CardNode.size.width + pad * 2,
            height: CardNode.size.height + pad * 2
        )
    }

    private func highlightDiscardTarget() {
        clearDiscardTarget()
        let zone = discardDropZone()
        let ring = SKShapeNode(rect: CGRect(x: -zone.width / 2, y: -zone.height / 2,
                                            width: zone.width, height: zone.height),
                               cornerRadius: 14)
        ring.position = CGPoint(x: zone.midX, y: zone.midY)
        ring.strokeColor = theme.turnGlow
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.alpha = 0
        ring.glowWidth = 6
        ring.zPosition = 200
        ring.run(SKAction.fadeAlpha(to: 0.85, duration: 0.15))
        addChild(ring)
        discardTargetRing = ring
    }

    private func clearDiscardTarget() {
        discardTargetRing?.removeFromParent()
        discardTargetRing = nil
    }
}

// Small helper to insert a child behind existing siblings (approximation via zPosition).
private extension SKNode {
    func insertChild(_ node: SKNode, at index: Int) {
        addChild(node)
        node.zPosition -= 0.001
    }
}
