import SpriteKit
import Combine
import UIKit

/// SpriteKit scene rendering the whole table.
///
/// Layout:
///   • Full-bleed twilight table with restrained ambient color.
///   • Turn/contract ribbon across the top and social seat pills at the edges.
///   • Stock + discard in the center, with public melds attached to owners.
///   • Adaptive hand fan along the bottom.
///   • Persistent inline meld tray and one contextual action at hand level.
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
    private let ambienceLayer = SKNode()
    private let headerLayer = SKNode()
    private let shadowsLayer = SKNode()
    private let pilesLayer = SKNode()
    private let seatsLayer = SKNode()
    private let meldsLayer = SKNode()
    private let stagingLayer = SKNode()
    private let handLayer = SKNode()
    private let actionLayer = SKNode()

    // Drag-and-drop state (M2d-a).
    private var draggingCard: CardNode?
    private var dragOrigin: CGPoint = .zero
    private var dragOriginRotation: CGFloat = 0
    private var dragOriginZ: CGFloat = 0
    private var draggingCardId: UUID?
    private var discardTargetRing: SKShapeNode?
    private var stagingBacking: SKShapeNode?
    private var meldTargetNodes: [UUID: SKShapeNode] = [:]
    private var meldCardNodes: [UUID: CardNode] = [:]
    private var lastRenderedHandOwnerId: UUID?
    private var lastRenderedHandIds: Set<UUID> = []
    private var isAnimatingTurnAction = false

    /// Slot centers captured during `buildHand`, used for drag reordering.
    private var handSlots: [(id: UUID, x: CGFloat, y: CGFloat)] = []

    init(size: CGSize, viewModel: GameViewModel, theme: VisualTheme = .gameNight) {
        self.vm = viewModel
        self.theme = theme
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = theme.background
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        buildStaticLayers()
        addChild(headerLayer)
        addChild(shadowsLayer)
        addChild(pilesLayer)
        addChild(seatsLayer)
        addChild(meldsLayer)
        addChild(stagingLayer)
        addChild(handLayer)
        addChild(actionLayer)
        rebuildDynamicLayers()
        subscribeToViewModel()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        buildStaticLayers()
        rebuildDynamicLayers()
    }

    // MARK: - Static table

    private func buildStaticLayers() {
        feltNode.removeFromParent()
        glowNode.removeFromParent()
        ambienceLayer.removeFromParent()
        ambienceLayer.removeAllChildren()

        // Full-bleed twilight table. The older inset felt/gold-rim treatment
        // made the scene resemble a desktop card-game skin.
        let rect = CGRect(origin: .zero, size: size)
        feltNode.path = CGPath(rect: rect, transform: nil)
        feltNode.fillColor = theme.feltFill
        feltNode.strokeColor = theme.feltStroke
        feltNode.lineWidth = theme.feltStrokeWidth
        feltNode.zPosition = -10
        addChild(feltNode)

        // Layered pools of color create depth without a literal felt texture.
        let center = SeatLayout.pileCenter(sceneSize: size)
        let glowSize: CGFloat = min(size.width, size.height) * 1.05
        glowNode.path = CGPath(ellipseIn: CGRect(x: -glowSize / 2, y: -glowSize / 2,
                                                 width: glowSize, height: glowSize),
                               transform: nil)
        glowNode.fillColor = theme.feltGlow.withAlphaComponent(0.14)
        glowNode.strokeColor = .clear
        glowNode.position = center
        glowNode.zPosition = -9
        glowNode.blendMode = .add
        addChild(glowNode)

        addAmbientGlow(at: CGPoint(x: size.width * 0.16, y: size.height * 0.12),
                       size: min(size.width, size.height) * 0.72,
                       color: theme.turnGlow.withAlphaComponent(0.055))
        addAmbientGlow(at: CGPoint(x: size.width * 0.88, y: size.height * 0.82),
                       size: min(size.width, size.height) * 0.86,
                       color: theme.feltGlow.withAlphaComponent(0.07))
        ambienceLayer.zPosition = -8
        addChild(ambienceLayer)
    }

    private func addAmbientGlow(at position: CGPoint, size diameter: CGFloat,
                               color: UIColor) {
        let glow = SKShapeNode(circleOfRadius: diameter / 2)
        glow.fillColor = color
        glow.strokeColor = .clear
        glow.position = position
        glow.blendMode = .add
        ambienceLayer.addChild(glow)
    }

    // MARK: - Dynamic layers (rebuild on state change)

    private func subscribeToViewModel() {
        // Rebuild on any published change (state, staging, etc.).
        vm.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // Defer to next runloop so vm's @Published sink fires after the
                // property is actually updated (objectWillChange fires *before*).
                DispatchQueue.main.async { self?.rebuildDynamicLayers() }
            }
            .store(in: &cancellables)
    }

    private func rebuildDynamicLayers() {
        buildHeader()
        shadowsLayer.removeAllChildren()
        buildPiles()
        buildSeats()
        buildMelds()
        buildStagingTray()
        buildHand()
        buildContextActions()
    }

    private func buildHeader() {
        headerLayer.removeAllChildren()

        let width = min(size.width - 300, 520)
        let height: CGFloat = 48
        let center = CGPoint(x: size.width / 2, y: size.height - 31)
        let panel = SKShapeNode(rectOf: CGSize(width: width, height: height),
                                cornerRadius: 24)
        panel.fillColor = theme.contractPillBg.withAlphaComponent(0.92)
        panel.strokeColor = theme.feltStroke
        panel.lineWidth = 1
        panel.position = center
        panel.zPosition = 30
        headerLayer.addChild(panel)

        let activeDot = SKShapeNode(circleOfRadius: 4)
        activeDot.fillColor = theme.turnGlow
        activeDot.strokeColor = .clear
        activeDot.position = CGPoint(x: center.x - width / 2 + 18,
                                     y: center.y + 9)
        activeDot.zPosition = 31
        headerLayer.addChild(activeDot)
        let pulse = SKAction.sequence([
            .fadeAlpha(to: 0.45, duration: 0.65),
            .fadeAlpha(to: 1.0, duration: 0.65),
        ])
        activeDot.run(.repeatForever(pulse))

        let turn = SKLabelNode(text: "\(vm.currentPlayerName)'s turn")
        turn.fontName = theme.titleFont
        turn.fontSize = 15
        turn.fontColor = theme.bannerText
        turn.horizontalAlignmentMode = .left
        turn.verticalAlignmentMode = .center
        turn.position = CGPoint(x: activeDot.position.x + 10,
                                y: center.y + 9)
        turn.zPosition = 31
        headerLayer.addChild(turn)

        let phase = SKLabelNode(text: phaseInstruction)
        phase.fontName = theme.bodyFont
        phase.fontSize = 11
        phase.fontColor = theme.seatSub
        phase.horizontalAlignmentMode = .left
        phase.verticalAlignmentMode = .center
        phase.position = CGPoint(x: turn.position.x, y: center.y - 10)
        phase.zPosition = 31
        headerLayer.addChild(phase)

        let contract = SKLabelNode(
            text: "HAND \(vm.state.currentRound)  •  LV \(vm.currentPlayer.currentLevel)  •  \(vm.currentContractDescription)"
        )
        contract.fontName = theme.titleFont
        contract.fontSize = 11
        contract.fontColor = theme.contractPillText
        contract.horizontalAlignmentMode = .right
        contract.verticalAlignmentMode = .center
        contract.position = CGPoint(x: center.x + width / 2 - 18,
                                    y: center.y)
        contract.zPosition = 31
        headerLayer.addChild(contract)
    }

    private var phaseInstruction: String {
        if vm.isOnlineGame && !vm.isLocalPlayersTurn {
            if vm.state.phase == .awaitingDraw {
                if vm.hasRequestedBuy {
                    return "Buy requested — waiting for \(vm.currentPlayerName)"
                }
                if vm.canRequestBuy {
                    return "Request the discard or wait for \(vm.currentPlayerName)"
                }
            }
            return "\(vm.currentPlayerName) is playing"
        }
        switch vm.state.phase {
        case .awaitingDraw:
            if let requester = vm.prioritizedBuyRequesterName {
                return "\(requester) wants to buy — discard has first refusal"
            }
            return "Choose the stock or discard pile"
        case .awaitingMeldOrDiscard:
            if vm.currentPlayer.hasGoneDownThisRound {
                if vm.currentPlayer.laidDownThisTurn {
                    return "Contract complete — drag a card to discard"
                }
                return "Lay off a card or drag one to discard"
            }
            return "Build your contract or drag a card to discard"
        case .roundEnded:
            return "Hand complete"
        case .gameEnded:
            return "Match complete"
        }
    }

    private func buildPiles() {
        pilesLayer.removeAllChildren()
        let center = SeatLayout.pileCenter(sceneSize: size)
        let gap: CGFloat = 34
        let pileScale: CGFloat = 0.90
        let pileWidth = CardNode.size.width * pileScale
        let pileHeight = CardNode.size.height * pileScale
        let zoneSize = CGSize(width: pileWidth + 24, height: pileHeight + 34)

        if let top = vm.state.stock.last {
            let stockPos = CGPoint(x: center.x - pileWidth / 2 - gap / 2,
                                   y: center.y)
            pilesLayer.addChild(pileZone(at: stockPos, size: zoneSize,
                                         name: "stock"))
            if vm.state.stock.count > 1 {
                let under = CardNode(card: top, faceUp: false, theme: theme)
                under.position = CGPoint(x: stockPos.x + 3, y: stockPos.y - 3)
                under.setScale(pileScale)
                under.zPosition = 3
                pilesLayer.addChild(under)
            }
            let stock = CardNode(card: top, faceUp: false, theme: theme)
            stock.setScale(pileScale)
            attachShadow(to: stock, at: stockPos, scale: pileScale)
            stock.position = stockPos
            stock.zPosition = 4
            stock.name = "stock"
            pilesLayer.addChild(stock)
            addPileCaption(at: CGPoint(
                x: stockPos.x,
                y: stockPos.y - pileHeight / 2 - 12
            ), title: "STOCK", count: vm.state.stock.count)
        }

        if !vm.state.discard.isEmpty {
            let basePos = CGPoint(x: center.x + pileWidth / 2 + gap / 2,
                                  y: center.y)
            pilesLayer.addChild(pileZone(at: basePos, size: zoneSize,
                                         name: "discard"))
            let recent = Array(vm.state.discard.suffix(3))
            for (i, card) in recent.enumerated() {
                let isTop = (i == recent.count - 1)
                let stackIdx = recent.count - 1 - i
                let offset = CGFloat(stackIdx) * 4
                let rotation = CGFloat(stackIdx) * -0.04
                let pos = CGPoint(x: basePos.x - offset, y: basePos.y + offset)
                let node = CardNode(card: card, faceUp: true, theme: theme)
                node.setScale(pileScale)
                node.position = pos
                node.zRotation = rotation
                node.zPosition = 4 + CGFloat(i)
                if isTop {
                    attachShadow(to: node, at: pos, rotation: rotation,
                                 scale: pileScale)
                    node.name = "discard"
                }
                pilesLayer.addChild(node)
            }
            addPileCaption(at: CGPoint(
                x: basePos.x,
                y: basePos.y - pileHeight / 2 - 12
            ), title: "DISCARD", count: vm.state.discard.count)
        }
    }

    private func pileZone(at position: CGPoint, size zoneSize: CGSize,
                          name: String) -> SKShapeNode {
        let zone = SKShapeNode(rectOf: zoneSize, cornerRadius: 16)
        zone.fillColor = theme.seatBgOther.withAlphaComponent(0.42)
        zone.strokeColor = theme.feltStroke.withAlphaComponent(0.75)
        zone.lineWidth = 1
        zone.position = CGPoint(x: position.x, y: position.y - 5)
        zone.zPosition = 1
        zone.name = name
        return zone
    }

    private func addPileCaption(at position: CGPoint, title: String, count: Int) {
        let label = SKLabelNode(text: "\(title)  \(count)")
        label.fontName = theme.titleFont
        label.fontSize = 9
        label.fontColor = theme.pileLabel
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = position
        label.zPosition = 8
        pilesLayer.addChild(label)
    }

    private func buildSeats() {
        seatsLayer.removeAllChildren()
        let seats = SeatLayout.seats(
            playerCount: vm.state.players.count,
            youIndex: vm.displayedPlayerIndex,
            sceneSize: size
        )
        for (i, player) in vm.state.players.enumerated() {
            let seat = seats[i]
            if seat.edge == .bottom {
                buildCurrentPlayerHUD(
                    player: player,
                    colorIndex: i,
                    isActive: i == vm.state.currentTurnIndex
                )
                continue
            }

            let bgWidth: CGFloat = 138
            let bgHeight: CGFloat = 42
            let bg = SKShapeNode(rectOf: CGSize(width: bgWidth, height: bgHeight),
                                 cornerRadius: 21)
            let isActive = i == vm.state.currentTurnIndex
            bg.fillColor = isActive ? theme.seatBgCurrent : theme.seatBgOther
            bg.strokeColor = isActive
                ? theme.turnGlow.withAlphaComponent(0.9)
                : theme.feltStroke.withAlphaComponent(0.7)
            bg.lineWidth = isActive ? 2 : 1
            bg.position = seat.anchor
            bg.zPosition = 2
            seatsLayer.addChild(bg)

            let avatarColor = theme.avatarColors[i % theme.avatarColors.count]
            let avatarRadius: CGFloat = 14
            let avatarX = seat.anchor.x - bgWidth / 2 + avatarRadius + 7
            let avatar = SKShapeNode(circleOfRadius: avatarRadius)
            avatar.fillColor = avatarColor
            avatar.strokeColor = UIColor.white.withAlphaComponent(0.75)
            avatar.lineWidth = 1
            avatar.position = CGPoint(x: avatarX, y: seat.anchor.y)
            avatar.zPosition = 3
            seatsLayer.addChild(avatar)
            let initial = SKLabelNode(text: String(player.name.prefix(1)).uppercased())
            initial.fontName = theme.titleFont
            initial.fontSize = 14
            initial.fontColor = .white
            initial.horizontalAlignmentMode = .center
            initial.verticalAlignmentMode = .center
            initial.position = CGPoint(x: avatarX, y: seat.anchor.y)
            initial.zPosition = 4
            seatsLayer.addChild(initial)

            let nameX = avatarX + avatarRadius + 7
            let title = SKLabelNode(text: player.name)
            title.fontName = theme.titleFont
            title.fontSize = 12
            title.fontColor = theme.seatTitle
            title.horizontalAlignmentMode = .left
            title.verticalAlignmentMode = .center
            title.position = CGPoint(x: nameX, y: seat.anchor.y + 7)
            title.zPosition = 3
            seatsLayer.addChild(title)

            let detail = SKLabelNode(
                text: "\(player.hand.count) cards  •  Lv \(player.currentLevel)"
            )
            detail.fontName = theme.bodyFont
            detail.fontSize = 9
            detail.fontColor = theme.seatSub
            detail.horizontalAlignmentMode = .left
            detail.verticalAlignmentMode = .center
            detail.position = CGPoint(x: nameX, y: seat.anchor.y - 8)
            detail.zPosition = 3
            seatsLayer.addChild(detail)
        }
    }

    private func buildMelds() {
        meldsLayer.removeAllChildren()
        meldTargetNodes.removeAll()
        meldCardNodes.removeAll()
        let seats = SeatLayout.seats(
            playerCount: vm.state.players.count,
            youIndex: vm.displayedPlayerIndex,
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
            if seat.edge == .bottom {
                drawOwnMeldsAboveHand(melds)
                continue
            }
            drawMelds(melds, near: seat)
        }
    }

    private func drawOwnMeldsAboveHand(_ melds: [Meld]) {
        let scale: CGFloat = 0.42
        let cardW = CardNode.size.width * scale
        let cardH = CardNode.size.height * scale
        let overlap: CGFloat = cardW * 0.42
        let meldGap: CGFloat = 14

        let widths = melds.map { CGFloat($0.cards.count - 1) * overlap + cardW }
        let totalWidth = widths.reduce(0, +) + CGFloat(melds.count - 1) * meldGap

        let rowY = tableauLaneY
        let minCenter = stagingTrayRect.minX + totalWidth / 2
        let maxCenter = stagingTrayRect.maxX - totalWidth / 2
        let centerX = minCenter <= maxCenter
            ? min(max(size.width / 2, minCenter), maxCenter)
            : size.width / 2
        var x = centerX - totalWidth / 2

        for (meldIndex, meld) in melds.enumerated() {
            let width = widths[meldIndex]
            addMeldTarget(for: meld,
                          rect: CGRect(x: x - 6, y: rowY - cardH / 2 - 5,
                                       width: width + 12, height: cardH + 10))
            for (idx, card) in meld.cards.enumerated() {
                let node = CardNode(card: card, faceUp: true, theme: theme)
                node.setScale(scale)
                let pos = CGPoint(x: x + CGFloat(idx) * overlap + cardW / 2, y: rowY)
                if idx == 0 { attachShadow(to: node, at: pos, scale: scale) }
                node.position = pos
                node.zPosition = 3 + CGFloat(idx) * 0.01
                node.name = "meld:\(meld.id.uuidString)"
                prepareMeldCardNode(node, card: card, in: meld)
                meldsLayer.addChild(node)
            }
            x += width + meldGap
        }
    }

    private func drawMelds(_ melds: [Meld], near seat: SeatLayout.Seat) {
        let useCompactMelds = (size.width < 720
            && (seat.edge == .left || seat.edge == .right))
            || (seat.edge == .top && vm.state.players.count >= 5)
        let scale: CGFloat = useCompactMelds ? 0.26 : 0.38
        let cardW = CardNode.size.width * scale
        let cardH = CardNode.size.height * scale
        let overlap: CGFloat = cardW * 0.42
        let meldGap: CGFloat = useCompactMelds ? 6 : 10
        let bgHalfHeight: CGFloat = 42 / 2
        let bgHalfWidth: CGFloat = 138 / 2

        let widths = melds.map { CGFloat($0.cards.count - 1) * overlap + cardW }
        let totalWidth = widths.reduce(0, +) + CGFloat(melds.count - 1) * meldGap

        let padding: CGFloat = 6
        let rowY: CGFloat
        let centerX: CGFloat
        switch seat.edge {
        case .left:
            rowY = seat.anchor.y
            centerX = seat.anchor.x + bgHalfWidth + padding + totalWidth / 2
        case .right:
            rowY = seat.anchor.y
            centerX = seat.anchor.x - bgHalfWidth - padding - totalWidth / 2
        case .top where vm.state.players.count < 5:
            rowY = seat.anchor.y
            centerX = seat.anchor.x - bgHalfWidth - padding - totalWidth / 2
        default:
            rowY = seat.anchor.y - bgHalfHeight - padding - cardH / 2
            let margin: CGFloat = 24
            centerX = min(max(seat.anchor.x, margin + totalWidth / 2),
                          size.width - margin - totalWidth / 2)
        }
        var x = centerX - totalWidth / 2

        for (meldIndex, meld) in melds.enumerated() {
            let width = widths[meldIndex]
            addMeldTarget(for: meld,
                          rect: CGRect(x: x - 5, y: rowY - cardH / 2 - 4,
                                       width: width + 10, height: cardH + 8))
            for (idx, card) in meld.cards.enumerated() {
                let node = CardNode(card: card, faceUp: true, theme: theme)
                node.setScale(scale)
                let pos = CGPoint(x: x + CGFloat(idx) * overlap + cardW / 2, y: rowY)
                if idx == 0 { attachShadow(to: node, at: pos, scale: scale) }
                node.position = pos
                node.zPosition = 3 + CGFloat(idx) * 0.01
                node.name = "meld:\(meld.id.uuidString)"
                prepareMeldCardNode(node, card: card, in: meld)
                meldsLayer.addChild(node)
            }
            x += width + meldGap
        }
    }

    private func prepareMeldCardNode(_ node: CardNode, card: Card, in meld: Meld) {
        meldCardNodes[card.id] = node
        if let representation = MeldValidator.representedNatural(
            for: card.id,
            in: meld
        ) {
            node.showWildRepresentation(representation)
        }
    }

    private func addMeldTarget(for meld: Meld, rect: CGRect) {
        let acceptsCard = vm.canPlayAnyHandCard(to: meld)
        let target = SKShapeNode(rect: rect, cornerRadius: 8)
        target.fillColor = theme.contractPillBg.withAlphaComponent(0.28)
        target.strokeColor = acceptsCard
            ? UIColor(red: 0.38, green: 0.86, blue: 0.66, alpha: 0.48)
            : theme.feltStroke.withAlphaComponent(0.45)
        target.lineWidth = acceptsCard ? 1.5 : 1
        target.zPosition = 2
        target.name = "meld:\(meld.id.uuidString)"
        meldsLayer.addChild(target)
        meldTargetNodes[meld.id] = target
    }

    private func buildCurrentPlayerHUD(
        player: Player,
        colorIndex: Int,
        isActive: Bool
    ) {
        let panelSize = CGSize(width: 174, height: 46)
        let center = CGPoint(x: horizontalEdgeInset + panelSize.width / 2,
                             y: stagingTrayY)
        let panel = SKShapeNode(rectOf: panelSize, cornerRadius: 23)
        panel.fillColor = isActive ? theme.seatBgCurrent : theme.seatBgOther
        panel.strokeColor = isActive
            ? theme.turnGlow.withAlphaComponent(0.85)
            : theme.feltStroke.withAlphaComponent(0.7)
        panel.lineWidth = isActive ? 1.5 : 1
        panel.position = center
        panel.zPosition = 2
        seatsLayer.addChild(panel)

        if isActive {
            let ringPulse = SKAction.sequence([
                .fadeAlpha(to: 0.5, duration: 0.7),
                .fadeAlpha(to: 1.0, duration: 0.7),
            ])
            panel.run(.repeatForever(ringPulse))
        }

        let avatarRadius: CGFloat = 15
        let avatarPosition = CGPoint(x: center.x - panelSize.width / 2 + 24,
                                     y: center.y)
        let avatarColor = theme.avatarColors[colorIndex % theme.avatarColors.count]
        let avatar = SKShapeNode(circleOfRadius: avatarRadius)
        avatar.fillColor = avatarColor
        avatar.strokeColor = UIColor.white.withAlphaComponent(0.8)
        avatar.lineWidth = 1
        avatar.position = avatarPosition
        avatar.zPosition = 3
        seatsLayer.addChild(avatar)
        let initial = SKLabelNode(text: String(player.name.prefix(1)).uppercased())
        initial.fontName = theme.titleFont
        initial.fontSize = 15
        initial.fontColor = .white
        initial.horizontalAlignmentMode = .center
        initial.verticalAlignmentMode = .center
        initial.position = avatarPosition
        initial.zPosition = 4
        seatsLayer.addChild(initial)

        let textX = avatarPosition.x + avatarRadius + 8
        let name = SKLabelNode(text: player.name)
        name.fontName = theme.titleFont
        name.fontSize = 12
        name.fontColor = theme.seatTitle
        name.horizontalAlignmentMode = .left
        name.verticalAlignmentMode = .center
        name.position = CGPoint(x: textX, y: center.y + 8)
        name.zPosition = 3
        seatsLayer.addChild(name)

        let ownMeldCount = vm.state.melds.filter { $0.ownerId == player.id }.count
        let status = ownMeldCount == 0
            ? "Lv \(player.currentLevel)  •  \(player.totalScore) pts"
            : "\(ownMeldCount) down  •  \(player.totalScore) pts"
        let detail = SKLabelNode(text: status)
        detail.fontName = theme.bodyFont
        detail.fontSize = 9
        detail.fontColor = theme.seatSub
        detail.horizontalAlignmentMode = .left
        detail.verticalAlignmentMode = .center
        detail.position = CGPoint(x: textX, y: center.y - 9)
        detail.zPosition = 3
        seatsLayer.addChild(detail)
    }

    private func buildHand() {
        handLayer.removeAllChildren()
        handSlots.removeAll()
        let hand = vm.unstagedCards
        let ownerId = vm.currentPlayer.id
        let currentIds = Set(vm.currentPlayer.hand.map(\.id))
        let newlyDrawnIds = lastRenderedHandOwnerId == ownerId
            ? currentIds.subtracting(lastRenderedHandIds)
            : []
        lastRenderedHandOwnerId = ownerId
        lastRenderedHandIds = currentIds
        guard !hand.isEmpty else { return }

        let cardWidth = CardNode.size.width
        let availableWidth = size.width - horizontalEdgeInset * 2 - 8
        let step: CGFloat
        if hand.count == 1 {
            step = 0
        } else {
            step = min(cardWidth + 8,
                       max(27, (availableWidth - cardWidth) / CGFloat(hand.count - 1)))
        }
        let totalWidth = cardWidth + CGFloat(hand.count - 1) * step
        let startX = (size.width - totalWidth) / 2 + cardWidth / 2
        let baseY: CGFloat = handRowY
        let maxLift: CGFloat = 8
        let maxAngle: CGFloat = 0.035

        for (i, card) in hand.enumerated() {
            let node = CardNode(card: card, faceUp: true, theme: theme)
            node.name = "card:\(card.id.uuidString)"
            let centeredIdx = CGFloat(i) - CGFloat(hand.count - 1) / 2
            let norm = centeredIdx / max(1, CGFloat(hand.count - 1) / 2)
            let lift = maxLift * (1 - norm * norm)
            let x = startX + CGFloat(i) * step
            let y = baseY + lift
            let angle = -norm * maxAngle
            let pos = CGPoint(x: x, y: y)
            node.zPosition = 4 + CGFloat(i) * 0.01
            if newlyDrawnIds.contains(card.id) {
                node.position = SeatLayout.pileCenter(sceneSize: size)
                node.zRotation = 0
                node.setScale(0.78)
                node.alpha = 0.25
                handLayer.addChild(node)

                let move = SKAction.move(to: pos, duration: 0.24)
                move.timingMode = .easeOut
                let settle = SKAction.group([
                    move,
                    .rotate(toAngle: angle, duration: 0.24,
                            shortestUnitArc: true),
                    .scale(to: 1.0, duration: 0.24),
                    .fadeAlpha(to: 1.0, duration: 0.16),
                ])
                node.run(settle) { [weak self, weak node] in
                    guard let self, let node else { return }
                    self.attachShadow(to: node, at: pos, rotation: angle)
                }
            } else {
                attachShadow(to: node, at: pos, rotation: angle)
                node.position = pos
                node.zRotation = angle
                handLayer.addChild(node)
            }
            handSlots.append((id: card.id, x: x, y: y))
        }
    }

    // MARK: - Layout constants

    private var handRowY: CGFloat {
        max(CardNode.size.height / 2 + 18, size.height * 0.15)
    }

    private var horizontalEdgeInset: CGFloat {
        size.width >= 780 ? 54 : 24
    }

    private var stagingTrayY: CGFloat {
        handRowY + CardNode.size.height / 2 + 36
    }

    private var stagingTrayRect: CGRect {
        let left = horizontalEdgeInset + 186
        let right = size.width - horizontalEdgeInset - 176
        let width = max(210, right - left)
        return CGRect(x: left, y: stagingTrayY - 28,
                      width: width, height: 56)
    }

    private var tableauLaneY: CGFloat { stagingTrayY }

    // MARK: - Inline staging and contextual actions

    private func buildStagingTray() {
        stagingLayer.removeAllChildren()
        stagingBacking = nil
        guard !vm.isCurrentPlayerCPU,
              vm.isLocalPlayersTurn,
              vm.state.phase == .awaitingMeldOrDiscard,
              !vm.currentPlayer.hasGoneDownThisRound else { return }

        let rect = stagingTrayRect
        let backing = SKShapeNode(rect: rect, cornerRadius: 18)
        backing.fillColor = theme.contractPillBg.withAlphaComponent(0.96)
        backing.strokeColor = stagingStatusColor.withAlphaComponent(0.8)
        backing.lineWidth = 1.5
        backing.zPosition = 12
        backing.name = "staging-zone"
        stagingLayer.addChild(backing)
        stagingBacking = backing

        let status = SKLabelNode(text: stagingStatusText)
        status.fontName = theme.titleFont
        status.fontSize = 10
        status.fontColor = stagingStatusColor
        status.horizontalAlignmentMode = .left
        status.verticalAlignmentMode = .center
        status.position = CGPoint(x: rect.minX + 14, y: rect.maxY - 13)
        status.zPosition = 14
        stagingLayer.addChild(status)

        let contentRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width - 54,
            height: rect.height
        )

        if vm.stagedCards.isEmpty {
            let hint = SKLabelNode(text: "Tap a card or drag it here")
            hint.fontName = theme.bodyFont
            hint.fontSize = 12
            hint.fontColor = theme.seatSub
            hint.horizontalAlignmentMode = .center
            hint.verticalAlignmentMode = .center
            hint.position = CGPoint(x: rect.midX, y: rect.midY - 8)
            hint.zPosition = 14
            stagingLayer.addChild(hint)
        } else {
            addStagedCards(in: contentRect)
            addSmallControl(
                title: "CLEAR",
                name: "clear-staging",
                at: CGPoint(x: rect.maxX - 26, y: rect.midY - 6),
                size: CGSize(width: 42, height: 26),
                to: stagingLayer
            )
        }

        addDraftChips(in: contentRect)
    }

    private func addStagedCards(in rect: CGRect) {
        let cards = vm.stagedCards
        let scale: CGFloat = 0.44
        let cardW = CardNode.size.width * scale
        let available = rect.width - 28
        let step: CGFloat
        if cards.count <= 1 {
            step = 0
        } else {
            step = min(cardW + 5,
                       max(0, (available - cardW) / CGFloat(cards.count - 1)))
        }
        let total = cardW + CGFloat(max(0, cards.count - 1)) * step
        let startX = rect.midX - total / 2 + cardW / 2
        for (index, card) in cards.enumerated() {
            let node = CardNode(card: card, faceUp: true, theme: theme)
            node.setScale(scale)
            node.position = CGPoint(x: startX + CGFloat(index) * step,
                                    y: rect.midY - 8)
            node.zPosition = 15 + CGFloat(index) * 0.01
            node.name = "staged-card:\(card.id.uuidString)"
            stagingLayer.addChild(node)
        }
    }

    private func addDraftChips(in rect: CGRect) {
        guard !vm.contractDraft.isEmpty else { return }
        let gap: CGFloat = 8
        let widths = vm.contractDraft.map { draft in
            let names = draft.map { CardNode.shortName($0) }
            return min(CGFloat(names.joined(separator: " ").count) * 5.4 + 24,
                150)
        }
        let total = widths.reduce(0, +) + CGFloat(widths.count - 1) * gap
        var x = max(rect.midX, rect.maxX - total - 10)
        for (index, draft) in vm.contractDraft.enumerated() {
            let width = widths[index]
            let center = CGPoint(x: x + width / 2, y: rect.maxY - 11)
            let chip = SKShapeNode(rectOf: CGSize(width: width, height: 22),
                                   cornerRadius: 11)
            chip.fillColor = UIColor(red: 0.12, green: 0.36, blue: 0.28, alpha: 0.96)
            chip.strokeColor = UIColor(red: 0.38, green: 0.86, blue: 0.66, alpha: 0.9)
            chip.lineWidth = 1
            chip.position = center
            chip.zPosition = 16
            chip.name = "draft-meld:\(index)"
            stagingLayer.addChild(chip)

            let cards = draft.map { CardNode.shortName($0) }.joined(separator: " ")
            let label = SKLabelNode(text: "✓ \(cards)")
            label.fontName = theme.titleFont
            label.fontSize = 9
            label.fontColor = UIColor(red: 0.72, green: 0.96, blue: 0.82, alpha: 1)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = center
            label.zPosition = 17
            label.name = "draft-meld:\(index)"
            stagingLayer.addChild(label)
            x += width + gap
        }
    }

    private func buildContextActions() {
        actionLayer.removeAllChildren()
        guard !vm.isCurrentPlayerCPU else { return }

        let action = contextAction
        addActionButton(title: action.title, name: action.name,
                        enabled: action.enabled, emphasized: action.emphasized)

        addSmallControl(title: "RANK", name: "sort-rank",
                        at: CGPoint(x: size.width - horizontalEdgeInset - 76,
                                    y: size.height - 31),
                        to: actionLayer)
        addSmallControl(title: "SUIT", name: "sort-suit",
                        at: CGPoint(x: size.width - horizontalEdgeInset - 24,
                                    y: size.height - 31),
                        to: actionLayer)
    }

    private var contextAction: (title: String, name: String?, enabled: Bool,
                                emphasized: Bool) {
        switch vm.state.phase {
        case .awaitingDraw:
            if vm.isLocalPlayersTurn {
                if let requester = vm.prioritizedBuyRequesterName {
                    return ("\(requester.uppercased()) WANTS TO BUY", nil, false, false)
                }
                return ("CHOOSE A PILE", nil, false, false)
            }
            if vm.hasRequestedBuy {
                return ("CANCEL BUY", "toggle-buy", true, false)
            }
            if vm.canRequestBuy {
                return ("BUY DISCARD", "toggle-buy", true, true)
            }
            return ("WAITING FOR \(vm.currentPlayerName.uppercased())", nil, false, false)
        case .awaitingMeldOrDiscard:
            if !vm.isLocalPlayersTurn {
                return ("\(vm.currentPlayerName.uppercased())'S TURN", nil, false, false)
            }
            if vm.currentPlayer.hasGoneDownThisRound {
                if vm.currentPlayer.laidDownThisTurn {
                    return ("DISCARD TO END", nil, false, false)
                }
                return ("TAP OR DRAG TO MELD", nil, false, false)
            }
            if vm.canConfirmGoDown {
                return ("GO DOWN", "go-down", true, true)
            }
            if case .some(.success(_)) = vm.stagedValidation {
                return ("SAVE MELD", "save-meld", true, true)
            }
            if !vm.stagedCardIds.isEmpty {
                return ("KEEP BUILDING", nil, false, false)
            }
            if !vm.contractDraft.isEmpty {
                return ("BUILD NEXT MELD", nil, false, false)
            }
            return ("TAP CARDS TO MELD", nil, false, false)
        case .roundEnded:
            return ("HAND COMPLETE", nil, false, false)
        case .gameEnded:
            return ("GAME COMPLETE", nil, false, false)
        }
    }

    private func addActionButton(title: String, name: String?, enabled: Bool,
                                 emphasized: Bool) {
        let width: CGFloat = 164
        let height: CGFloat = 46
        let center = CGPoint(x: size.width - horizontalEdgeInset - width / 2,
                             y: stagingTrayY)
        let button = SKShapeNode(rectOf: CGSize(width: width, height: height),
                                 cornerRadius: 23)
        button.fillColor = enabled
            ? theme.turnGlow
            : theme.contractPillBg.withAlphaComponent(0.82)
        button.strokeColor = enabled
            ? UIColor.white.withAlphaComponent(0.45)
            : theme.feltStroke.withAlphaComponent(0.6)
        button.lineWidth = enabled ? 1.5 : 1
        button.position = center
        button.zPosition = 20
        button.name = name
        actionLayer.addChild(button)

        let label = SKLabelNode(text: title)
        label.fontName = theme.titleFont
        label.fontSize = 12
        label.fontColor = enabled ? theme.blackSuit : theme.seatSub
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = center
        label.zPosition = 21
        label.name = name
        actionLayer.addChild(label)

        if emphasized {
            let pulse = SKAction.sequence([
                .scale(to: 1.045, duration: 0.55),
                .scale(to: 1.0, duration: 0.55),
            ])
            button.run(.repeatForever(pulse))
        }
    }

    private func addSmallControl(
        title: String,
        name: String,
        at position: CGPoint,
        size controlSize: CGSize = CGSize(width: 48, height: 40),
        to layer: SKNode
    ) {
        let button = SKShapeNode(rectOf: controlSize,
                                 cornerRadius: controlSize.height / 2)
        button.fillColor = theme.contractPillBg
        button.strokeColor = theme.feltStroke.withAlphaComponent(0.8)
        button.lineWidth = 1
        button.position = position
        button.zPosition = 25
        button.name = name
        layer.addChild(button)

        let label = SKLabelNode(text: title)
        label.fontName = theme.titleFont
        label.fontSize = controlSize.height < 30 ? 7 : 8
        label.fontColor = theme.seatSub
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = position
        label.zPosition = 26
        label.name = name
        layer.addChild(label)
    }

    private var stagingStatusText: String {
        switch vm.stagedValidation {
        case .none:
            if vm.canConfirmGoDown { return "CONTRACT READY" }
            if !vm.contractDraft.isEmpty { return "BUILD NEXT MELD" }
            return vm.goDownProgressText.uppercased()
        case .some(.success(let kind)):
            let type = kind == .triplet ? "SET" : "RUN"
            return "VALID \(type)  •  \(vm.stagedCards.count) CARDS"
        case .some(.failure(let error)):
            return error.description.uppercased()
        }
    }

    private var stagingStatusColor: UIColor {
        switch vm.stagedValidation {
        case .some(.success(_)):
            return UIColor(red: 0.38, green: 0.86, blue: 0.66, alpha: 1)
        case .some(.failure(_)):
            return UIColor(red: 0.96, green: 0.42, blue: 0.45, alpha: 1)
        case .none:
            return theme.contractPillText
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
        guard !isAnimatingTurnAction, let touch = touches.first else { return }
        let point = touch.location(in: self)

        if let name = interactiveName(at: point),
           handleImmediateControl(name) {
            return
        }

        if let uuid = Self.handCardId(
            at: point,
            slots: handSlots,
            cardSize: CardNode.size
        ), let hit = handLayer.children.first(where: {
            $0.name == "card:\(uuid.uuidString)"
        }) as? CardNode {
            beginDrag(card: hit, id: uuid)
            return
        }

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

        guard draggingCard != nil else { return }

        if let id = draggingCardId,
           let card = vm.currentPlayer.hand.first(where: { $0.id == id }) {
            if vm.isLocalPlayersTurn,
               vm.state.phase == .awaitingMeldOrDiscard,
               discardDropZone().contains(point) {
                guard let node = draggingCard else { return }
                animateDiscard(card, node: node)
                return
            }

            if vm.isLocalPlayersTurn,
               vm.state.phase == .awaitingMeldOrDiscard,
               !vm.currentPlayer.hasGoneDownThisRound,
               stagingTrayRect.contains(point) {
                vm.toggleStaged(cardId: id)
                selectionFeedback()
                completeDrag()
                return
            }

            if let meldId = meldId(at: point, for: card) {
                if vm.playHandCard(card, to: meldId) {
                    successFeedback()
                    completeDrag()
                } else {
                    warningFeedback()
                    cancelDrag()
                }
                return
            }

            let dx = point.x - dragOrigin.x
            let dy = point.y - dragOrigin.y
            let tapThreshold: CGFloat = 10
            if abs(dx) < tapThreshold && abs(dy) < tapThreshold {
                guard vm.isLocalPlayersTurn,
                      vm.state.phase == .awaitingMeldOrDiscard else {
                    warningFeedback()
                    cancelDrag()
                    return
                }
                if vm.currentPlayer.hasGoneDownThisRound {
                    if vm.playTappedHandCard(card) {
                        successFeedback()
                        completeDrag()
                    } else {
                        warningFeedback()
                        cancelDrag()
                    }
                    return
                }
                vm.toggleStaged(cardId: id)
                selectionFeedback()
                completeDrag()
                return
            }

            if isInHandRowBand(point) {
                let targetId = reorderTargetId(forDropX: point.x, draggedId: id)
                vm.moveHandCard(id, before: targetId)
                completeDrag()
                rebuildDynamicLayers()
                return
            }
        }

        cancelDrag()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelDrag()
    }

    private func handleImmediateControl(_ name: String) -> Bool {
        switch name {
        case "stock":
            guard vm.canDrawFromStock else {
                warningFeedback()
                return true
            }
            let previousPhase = vm.state.phase
            vm.drawFromStock()
            if previousPhase != vm.state.phase { selectionFeedback() }
            return true
        case "discard":
            guard vm.canDrawFromDiscard else {
                warningFeedback()
                return true
            }
            let previousPhase = vm.state.phase
            vm.drawFromDiscard()
            if previousPhase != vm.state.phase { selectionFeedback() }
            return true
        case "toggle-buy":
            let wasRequested = vm.hasRequestedBuy
            vm.toggleLocalBuyRequest()
            if wasRequested != vm.hasRequestedBuy {
                selectionFeedback()
            }
            return true
        case "save-meld":
            if vm.saveStagedAsMeld() {
                successFeedback()
            } else {
                warningFeedback()
            }
            return true
        case "go-down":
            if vm.confirmGoDown() {
                successFeedback()
            } else {
                warningFeedback()
            }
            return true
        case "clear-staging":
            vm.clearStaging()
            selectionFeedback()
            return true
        case "sort-rank":
            vm.sortHandByRank()
            selectionFeedback()
            return true
        case "sort-suit":
            vm.sortHandBySuit()
            selectionFeedback()
            return true
        default:
            break
        }

        if name.hasPrefix("staged-card:"),
           let id = uuidSuffix(in: name) {
            vm.toggleStaged(cardId: id)
            selectionFeedback()
            return true
        }
        if name.hasPrefix("draft-meld:"),
           let index = Int(name.split(separator: ":").last ?? "") {
            vm.removeDraftMeld(at: index)
            selectionFeedback()
            return true
        }
        return false
    }

    private func interactiveName(at point: CGPoint) -> String? {
        for node in nodes(at: point) {
            var candidate: SKNode? = node
            while let current = candidate {
                if let name = current.name { return name }
                candidate = current.parent
            }
        }
        return nil
    }

    private func uuidSuffix(in name: String) -> UUID? {
        guard let suffix = name.split(separator: ":").last else { return nil }
        return UUID(uuidString: String(suffix))
    }

    private func meldId(at point: CGPoint, for card: Card) -> UUID? {
        let pointInMeldLayer = meldsLayer.convert(point, from: self)
        let targetFrames = meldTargetNodes.mapValues { $0.frame }
        let eligibleIds = Set(vm.state.melds.compactMap {
            vm.canPlay(card, to: $0) ? $0.id : nil
        })
        return Self.meldTargetId(
            at: pointInMeldLayer,
            targetFrames: targetFrames,
            eligibleIds: eligibleIds
        )
    }

    static func meldTargetId(
        at point: CGPoint,
        targetFrames: [UUID: CGRect],
        eligibleIds: Set<UUID>
    ) -> UUID? {
        targetFrames
            .filter { eligibleIds.contains($0.key) && $0.value.contains(point) }
            .min { lhs, rhs in
                let lhsCenter = CGPoint(x: lhs.value.midX, y: lhs.value.midY)
                let rhsCenter = CGPoint(x: rhs.value.midX, y: rhs.value.midY)
                let lhsDistance = squaredDistance(from: point, to: lhsCenter)
                let rhsDistance = squaredDistance(from: point, to: rhsCenter)
                if lhsDistance == rhsDistance {
                    return lhs.key.uuidString < rhs.key.uuidString
                }
                return lhsDistance < rhsDistance
            }?
            .key
    }

    private static func squaredDistance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

    // MARK: - Hand reorder helpers (M2f)

    /// True if `point` sits in the vertical band occupied by the hand fan —
    /// used to distinguish "drop back to reorder" from "cancel drag".
    private func isInHandRowBand(_ point: CGPoint) -> Bool {
        let halfH = CardNode.size.height * 0.75
        let center = handRowY
        return point.y >= center - halfH && point.y <= center + halfH
    }

    static func handCardId(
        at point: CGPoint,
        slots: [(id: UUID, x: CGFloat, y: CGFloat)],
        cardSize: CGSize
    ) -> UUID? {
        let halfWidth = cardSize.width / 2
        let halfHeight = cardSize.height / 2 + 4
        for index in slots.indices {
            let slot = slots[index]
            guard point.y >= slot.y - halfHeight,
                  point.y <= slot.y + halfHeight else { continue }

            let left = slot.x - halfWidth
            let fullRight = slot.x + halfWidth
            let visibleRight: CGFloat
            if index < slots.index(before: slots.endIndex) {
                let nextLeft = slots[index + 1].x - halfWidth
                visibleRight = min(fullRight, nextLeft)
            } else {
                visibleRight = fullRight
            }
            let includesRightEdge = index == slots.index(before: slots.endIndex)
            if point.x >= left,
               point.x < visibleRight || (includesRightEdge && point.x <= visibleRight) {
                return slot.id
            }
        }
        return nil
    }

    private func reorderTargetId(forDropX x: CGFloat, draggedId: UUID) -> UUID? {
        let slots = handSlots.filter { $0.id != draggedId }
        for slot in slots where x < slot.x {
            return slot.id
        }
        return nil
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
        guard let value = vm.currentPlayer.hand.first(where: { $0.id == id }) else {
            return
        }
        if vm.isLocalPlayersTurn,
           vm.state.phase == .awaitingMeldOrDiscard {
            highlightDiscardTarget()
            if vm.currentPlayer.hasGoneDownThisRound {
                highlightCompatibleMeldTargets(for: value)
            } else {
                highlightStagingTarget()
            }
        }
    }

    private func cancelDrag() {
        guard let card = draggingCard else {
            clearDragTargets()
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
        clearDragTargets()
    }

    private func completeDrag() {
        draggingCard = nil
        draggingCardId = nil
        clearDragTargets()
    }

    private func animateDiscard(_ card: Card, node: CardNode) {
        isAnimatingTurnAction = true
        draggingCard = nil
        draggingCardId = nil
        clearDragTargets()

        node.zPosition = 600
        let move = SKAction.move(to: CGPoint(x: discardDropZone().midX,
                                             y: discardDropZone().midY),
                                 duration: 0.20)
        move.timingMode = .easeIn
        let animation = SKAction.group([
            move,
            .rotate(toAngle: -0.03, duration: 0.20,
                    shortestUnitArc: true),
            .scale(to: 0.90, duration: 0.20),
        ])
        node.run(animation) { [weak self] in
            guard let self else { return }
            let ok = self.vm.dispatch(
                .discard(playerId: self.vm.currentPlayer.id, card: card)
            )
            self.isAnimatingTurnAction = false
            if ok {
                self.successFeedback()
            } else {
                self.warningFeedback()
                self.rebuildDynamicLayers()
            }
        }
    }

    /// The tappable/droppable rectangle around the discard pile, in scene
    /// coordinates. Slightly larger than the pile visual for easier drops.
    private func discardDropZone() -> CGRect {
        let center = SeatLayout.pileCenter(sceneSize: size)
        let gap: CGFloat = 34
        let pileScale: CGFloat = 0.90
        let pileWidth = CardNode.size.width * pileScale
        let pileHeight = CardNode.size.height * pileScale
        let basePos = CGPoint(x: center.x + pileWidth / 2 + gap / 2,
                              y: center.y)
        let pad: CGFloat = 24
        return CGRect(
            x: basePos.x - pileWidth / 2 - pad,
            y: basePos.y - pileHeight / 2 - pad,
            width: pileWidth + pad * 2,
            height: pileHeight + pad * 2
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

    private func highlightStagingTarget() {
        stagingBacking?.strokeColor = theme.turnGlow
        stagingBacking?.lineWidth = 3
        stagingBacking?.glowWidth = 4
    }

    private func highlightCompatibleMeldTargets(for card: Card) {
        for meld in vm.state.melds where vm.canPlay(card, to: meld) {
            guard let target = meldTargetNodes[meld.id] else { continue }
            target.strokeColor = UIColor(red: 0.38, green: 0.86, blue: 0.66, alpha: 1)
            target.lineWidth = 3
            target.glowWidth = 5
            if let wildCardId = vm.redemptionWildCardId(for: card, in: meld) {
                meldCardNodes[wildCardId]?.setDropTargetHighlighted(true)
            }
        }
    }

    private func clearDragTargets() {
        clearDiscardTarget()
        stagingBacking?.strokeColor = stagingStatusColor.withAlphaComponent(0.8)
        stagingBacking?.lineWidth = 1.5
        stagingBacking?.glowWidth = 0
        for node in meldCardNodes.values {
            node.setDropTargetHighlighted(false)
        }
        for meld in vm.state.melds {
            guard let target = meldTargetNodes[meld.id] else { continue }
            let acceptsCard = vm.canPlayAnyHandCard(to: meld)
            target.strokeColor = acceptsCard
                ? UIColor(red: 0.38, green: 0.86, blue: 0.66, alpha: 0.48)
                : theme.feltStroke.withAlphaComponent(0.45)
            target.lineWidth = acceptsCard ? 1.5 : 1
            target.glowWidth = 0
        }
    }

    private func clearDiscardTarget() {
        discardTargetRing?.removeFromParent()
        discardTargetRing = nil
    }

    private func selectionFeedback() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func successFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func warningFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
