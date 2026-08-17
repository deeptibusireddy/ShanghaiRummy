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

    enum CardDropTarget: Equatable {
        case discard
        case meld(UUID)
    }

    private let vm: GameViewModel
    private let theme: VisualTheme
    private var cancellables: Set<AnyCancellable> = []
    private var tableSafeAreaInsets: UIEdgeInsets = .zero

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
    private var dragOriginScale: CGFloat = 1
    private var dragTouchOrigin: CGPoint = .zero
    private var draggingCardId: UUID?
    private var dragAllowsGameplay = false
    private var discardTargetRing: SKShapeNode?
    private var stagingBacking: SKShapeNode?
    private var meldTargetNodes: [UUID: SKShapeNode] = [:]
    private var meldCardNodes: [UUID: CardNode] = [:]
    private var lastRenderedHandOwnerId: UUID?
    private var lastRenderedHandIds: Set<UUID> = []
    private var isAnimatingTurnAction = false
    private var lastObservedTurnRound: Int?
    private var lastObservedTurnPlayerId: UUID?

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

    func updateLayout(size newSize: CGSize, safeAreaInsets newInsets: UIEdgeInsets) {
        let sizeChanged = size != newSize
        let insetsChanged = tableSafeAreaInsets != newInsets
        tableSafeAreaInsets = newInsets

        if sizeChanged {
            size = newSize
        } else if insetsChanged, view != nil {
            buildStaticLayers()
            rebuildDynamicLayers()
        }
    }

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
        vm.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.playTurnAlertIfNeeded(for: state)
            }
            .store(in: &cancellables)

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
        guard hasUsableLayoutSize else { return }
        abandonDragForRebuild()
        buildHeader()
        shadowsLayer.removeAllChildren()
        buildPiles()
        buildSeats()
        buildMelds()
        buildStagingTray()
        buildHand()
        buildContextActions()
    }

    private func playTurnAlertIfNeeded(for state: GameState) {
        let currentRound = state.currentRound
        let currentPlayerId = state.currentPlayerId
        let shouldPlay = Self.shouldPlayTurnAlert(
            previousRound: lastObservedTurnRound,
            previousPlayerId: lastObservedTurnPlayerId,
            currentRound: currentRound,
            currentPlayerId: currentPlayerId,
            localPlayerId: vm.localPlayerId,
            cpuPlayerIds: vm.cpuPlayerIds,
            phase: state.phase
        )
        lastObservedTurnRound = currentRound
        lastObservedTurnPlayerId = currentPlayerId

        guard shouldPlay,
              UIApplication.shared.applicationState == .active else {
            return
        }
        run(.playSoundFileNamed("turn-chime.wav", waitForCompletion: false))
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: 0.75)
    }

    static func shouldPlayTurnAlert(
        previousRound: Int?,
        previousPlayerId: UUID?,
        currentRound: Int,
        currentPlayerId: UUID,
        localPlayerId: UUID?,
        cpuPlayerIds: Set<UUID>,
        phase: GameState.Phase
    ) -> Bool {
        guard let previousRound,
              let previousPlayerId,
              (previousRound != currentRound
                || previousPlayerId != currentPlayerId),
              (phase == .awaitingDraw
                || phase == .awaitingMeldOrDiscard),
              !cpuPlayerIds.contains(currentPlayerId) else {
            return false
        }
        return localPlayerId == nil || localPlayerId == currentPlayerId
    }

    private func buildHeader() {
        headerLayer.removeAllChildren()

        let activePlayer = vm.turnPlayer
        let frame = Self.turnBannerFrame(
            sceneSize: size,
            horizontalEdgeInset: horizontalEdgeInset
        )
        let width = frame.width
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let panel = SKShapeNode(rectOf: frame.size,
                                cornerRadius: 24)
        panel.fillColor = theme.contractPillBg.withAlphaComponent(0.92)
        panel.strokeColor = theme.turnGlow.withAlphaComponent(0.9)
        panel.lineWidth = 2.5
        panel.glowWidth = 2
        panel.position = center
        panel.zPosition = 30
        headerLayer.addChild(panel)

        let activeDot = SKShapeNode(circleOfRadius: 6)
        activeDot.fillColor = theme.turnGlow
        activeDot.strokeColor = .clear
        activeDot.glowWidth = 4
        activeDot.position = CGPoint(x: center.x - width / 2 + 18,
                                     y: center.y + 9)
        activeDot.zPosition = 31
        headerLayer.addChild(activeDot)
        let pulse = SKAction.sequence([
            .fadeAlpha(to: 0.45, duration: 0.65),
            .fadeAlpha(to: 1.0, duration: 0.65),
        ])
        activeDot.run(.repeatForever(pulse))

        let turn = SKLabelNode(text: Self.turnTitle(
            playerName: activePlayer.name,
            isLocalPlayersTurn: vm.isLocalPlayersTurn,
            isCPU: vm.isCurrentPlayerCPU
        ))
        turn.fontName = theme.titleFont
        turn.fontSize = size.width < 720 ? 14 : 17
        turn.fontColor = theme.turnGlow
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

        let handCount = SKLabelNode(
            text: Self.cardCountLabel(activePlayer.hand.count).uppercased()
        )
        handCount.fontName = theme.titleFont
        handCount.fontSize = size.width < 720 ? 11 : 13
        handCount.fontColor = theme.turnGlow
        handCount.horizontalAlignmentMode = .right
        handCount.verticalAlignmentMode = .center
        handCount.position = CGPoint(x: center.x + width / 2 - 18,
                                     y: center.y + 9)
        handCount.zPosition = 31
        headerLayer.addChild(handCount)

        let contract = SKLabelNode(
            text: "LV \(activePlayer.currentLevel)  •  \(vm.turnPlayerContractDescription)"
        )
        contract.fontName = theme.titleFont
        contract.fontSize = size.width < 720 ? 9 : 10
        contract.fontColor = theme.contractPillText
        contract.horizontalAlignmentMode = .right
        contract.verticalAlignmentMode = .center
        contract.position = CGPoint(x: center.x + width / 2 - 18,
                                    y: center.y - 10)
        contract.zPosition = 31
        headerLayer.addChild(contract)
    }

    private var phaseInstruction: String {
        if vm.isBuyDecisionActive {
            return "Purchase round in progress"
        }
        if vm.isCurrentPlayerCPU {
            return "Playing automatically"
        }
        if vm.isOnlineGame && !vm.isLocalPlayersTurn {
            return "Waiting for their move"
        }
        switch vm.state.phase {
        case .awaitingDraw:
            return "Choose how to draw"
        case .awaitingMeldOrDiscard:
            if vm.currentPlayer.hasGoneDownThisRound {
                if vm.currentPlayer.laidDownThisTurn {
                    return "Contract complete — discard"
                }
                return "Lay off or discard"
            }
            return "Build contract or discard"
        case .roundEnded:
            return "Hand complete"
        case .gameEnded:
            return "Match complete"
        }
    }

    private func buildPiles() {
        pilesLayer.removeAllChildren()
        let center = SeatLayout.pileCenter(sceneSize: size)
        let gap = Self.pileGap
        let pileScale = Self.pileScale
        let pileWidth = CardNode.size.width * pileScale
        let pileHeight = CardNode.size.height * pileScale
        let zoneSize = Self.pileZoneSize

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
            sceneSize: size,
            horizontalInset: seatLayoutHorizontalInset
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

            let bgWidth = opponentSeatWidth
            let usesCompactSeat = vm.state.players.count >= 5 || bgWidth < 100
            let bgHeight: CGFloat = usesCompactSeat ? 38 : 42
            let bg = SKShapeNode(rectOf: CGSize(width: bgWidth, height: bgHeight),
                                 cornerRadius: bgHeight / 2)
            let isActive = i == vm.state.currentTurnIndex
            if isActive {
                addActiveTurnHalo(
                    at: seat.anchor,
                    size: CGSize(width: bgWidth, height: bgHeight),
                    to: seatsLayer
                )
            }
            bg.fillColor = isActive ? theme.seatBgCurrent : theme.seatBgOther
            bg.strokeColor = isActive
                ? theme.turnGlow.withAlphaComponent(0.9)
                : theme.feltStroke.withAlphaComponent(0.7)
            bg.lineWidth = isActive ? 3 : 1
            bg.position = seat.anchor
            bg.zPosition = 2
            seatsLayer.addChild(bg)

            let avatarColor = theme.avatarColors[i % theme.avatarColors.count]
            let avatarRadius: CGFloat = usesCompactSeat ? 11 : 14
            let avatarInset: CGFloat = usesCompactSeat ? 5 : 7
            let avatarX = seat.anchor.x - bgWidth / 2 + avatarRadius + avatarInset
            let avatar = SKShapeNode(circleOfRadius: avatarRadius)
            avatar.fillColor = avatarColor
            avatar.strokeColor = isActive
                ? theme.turnGlow
                : UIColor.white.withAlphaComponent(0.75)
            avatar.lineWidth = isActive ? 2.5 : 1
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

            let nameX = avatarX + avatarRadius + (usesCompactSeat ? 5 : 7)
            let displayedName = usesCompactSeat
                ? String(player.name.prefix(bgWidth < 100 ? 4 : 7))
                : player.name
            let title = SKLabelNode(text: displayedName)
            title.fontName = theme.titleFont
            title.fontSize = usesCompactSeat ? 10 : 12
            title.fontColor = isActive ? theme.turnGlow : theme.seatTitle
            title.horizontalAlignmentMode = .left
            title.verticalAlignmentMode = .center
            title.position = CGPoint(x: nameX, y: seat.anchor.y + 7)
            title.zPosition = 3
            seatsLayer.addChild(title)

            let detail = SKLabelNode(
                text: usesCompactSeat
                    ? "\(player.hand.count) • L\(player.currentLevel)"
                    : "\(Self.cardCountLabel(player.hand.count))  •  Lv \(player.currentLevel)"
            )
            detail.fontName = theme.bodyFont
            detail.fontSize = usesCompactSeat ? 8 : 9
            detail.fontColor = isActive ? theme.turnGlow : theme.seatSub
            detail.horizontalAlignmentMode = .left
            detail.verticalAlignmentMode = .center
            detail.position = CGPoint(x: nameX, y: seat.anchor.y - 8)
            detail.zPosition = 3
            seatsLayer.addChild(detail)
        }
    }

    private func addActiveTurnHalo(
        at position: CGPoint,
        size: CGSize,
        to layer: SKNode
    ) {
        let haloSize = CGSize(width: size.width + 10, height: size.height + 10)
        let halo = SKShapeNode(
            rectOf: haloSize,
            cornerRadius: haloSize.height / 2
        )
        halo.fillColor = .clear
        halo.strokeColor = theme.turnGlow
        halo.lineWidth = 3
        halo.glowWidth = 6
        halo.alpha = 0.95
        halo.position = position
        halo.zPosition = 1
        halo.name = "active-turn-halo"
        layer.addChild(halo)

        let pulseOut = SKAction.group([
            .scale(to: 1.035, duration: 0.65),
            .fadeAlpha(to: 0.55, duration: 0.65),
        ])
        let pulseIn = SKAction.group([
            .scale(to: 1.0, duration: 0.65),
            .fadeAlpha(to: 0.95, duration: 0.65),
        ])
        halo.run(.repeatForever(.sequence([pulseOut, pulseIn])))
    }

    private func buildMelds() {
        meldsLayer.removeAllChildren()
        meldTargetNodes.removeAll()
        meldCardNodes.removeAll()
        let seats = SeatLayout.seats(
            playerCount: vm.state.players.count,
            youIndex: vm.displayedPlayerIndex,
            sceneSize: size,
            horizontalInset: seatLayoutHorizontalInset
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
        let meldGap = Self.ownMeldGap
        let scale = ownMeldScale(for: melds, meldGap: meldGap)
        let cardW = CardNode.size.width * scale
        let cardH = CardNode.size.height * scale
        let cardStepFraction = Self.fittedMeldStepFraction(
            cardCounts: melds.map(\.cards.count),
            scale: scale,
            desiredStepFraction: Self.meldCardStepFraction,
            meldGap: meldGap,
            availableWidth: stagingTrayRect.width,
            targetPadding: 16
        )
        let overlap: CGFloat = cardW * cardStepFraction

        let widths = melds.map { CGFloat($0.cards.count - 1) * overlap + cardW }
        let totalWidth = widths.reduce(0, +) + CGFloat(melds.count - 1) * meldGap

        let rowY = ownMeldRowY(scale: scale)
        let minCenter = stagingTrayRect.minX + totalWidth / 2
        let maxCenter = stagingTrayRect.maxX - totalWidth / 2
        let centerX = minCenter <= maxCenter
            ? min(max(size.width / 2, minCenter), maxCenter)
            : size.width / 2
        var x = centerX - totalWidth / 2

        for (meldIndex, meld) in melds.enumerated() {
            let width = widths[meldIndex]
            addMeldTarget(for: meld,
                          rect: CGRect(x: x - 8, y: rowY - cardH / 2 - 5,
                                       width: width + 16, height: cardH + 10))
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

    private enum MeldRowAlignment {
        case leading
        case center
        case trailing
    }

    private func drawMelds(_ melds: [Meld], near seat: SeatLayout.Seat) {
        let seatHalfWidth = opponentSeatWidth / 2
        let seatPadding: CGFloat = 6
        let edgeMargin: CGFloat = 24
        let meldGap = melds.count > 2
            ? Self.crowdedOpponentMeldGap
            : Self.standardOpponentMeldGap
        let desiredScale = preferredOpponentMeldScaleForLayout
        let minimumScale = Self.minimumMeldScale
        let pileCorridorHalfWidth = Self.protectedPileCorridorHalfWidth

        switch seat.edge {
        case .left, .right:
            let bounds: ClosedRange<CGFloat>
            let alignment: MeldRowAlignment
            if seat.edge == .left {
                bounds = (seat.anchor.x + seatHalfWidth + seatPadding)...(
                    size.width / 2 - pileCorridorHalfWidth
                )
                alignment = .leading
            } else {
                bounds = (size.width / 2 + pileCorridorHalfWidth)...(
                    seat.anchor.x - seatHalfWidth - seatPadding
                )
                alignment = .trailing
            }
            drawSideMeldRows(
                melds,
                bounds: bounds,
                alignment: alignment,
                seatY: seat.anchor.y,
                desiredScale: desiredScale,
                minimumScale: minimumScale,
                meldGap: meldGap
            )

        case .top where vm.state.players.count < 5:
            let bounds = edgeMargin...(
                seat.anchor.x - seatHalfWidth - seatPadding
            )
            let rowScale = fittedScale(
                for: melds,
                desiredScale: desiredScale,
                minimumScale: minimumScale,
                meldGap: meldGap,
                availableWidth: max(0, bounds.upperBound - bounds.lowerBound)
            )
            let rowY = Self.centerTopMeldRowY(
                sceneSize: size,
                seatY: seat.anchor.y,
                horizontalEdgeInset: horizontalEdgeInset,
                meldScale: rowScale
            )
            drawFittedMeldRow(
                melds,
                bounds: bounds,
                rowY: rowY,
                alignment: .trailing,
                desiredScale: desiredScale,
                minimumScale: minimumScale,
                meldGap: meldGap
            )

        case .top:
            drawCenterTopMeldWings(
                melds,
                seatY: seat.anchor.y,
                desiredScale: desiredScale,
                minimumScale: minimumScale,
                meldGap: meldGap
            )

        case .topLeft, .topRight:
            let bounds: ClosedRange<CGFloat>
            if seat.edge == .topLeft {
                bounds = edgeMargin...(
                    size.width / 2 - pileCorridorHalfWidth
                )
            } else {
                bounds = (size.width / 2 + pileCorridorHalfWidth)...(
                    size.width - edgeMargin
                )
            }
            let rowScale = fittedScale(
                for: melds,
                desiredScale: desiredScale,
                minimumScale: minimumScale,
                meldGap: meldGap,
                availableWidth: max(0, bounds.upperBound - bounds.lowerBound)
            )
            let rowY = Self.topCornerMeldRowY(
                sceneSize: size,
                seatY: seat.anchor.y,
                horizontalEdgeInset: horizontalEdgeInset,
                playerCount: vm.state.players.count,
                cornerMeldScale: rowScale,
                centerMeldScale: desiredScale
            )
            drawFittedMeldRow(
                melds,
                bounds: bounds,
                rowY: rowY,
                alignment: .center,
                desiredScale: desiredScale,
                minimumScale: minimumScale,
                meldGap: meldGap
            )

        case .bottom:
            break
        }
    }

    private func drawSideMeldRows(
        _ melds: [Meld],
        bounds: ClosedRange<CGFloat>,
        alignment: MeldRowAlignment,
        seatY: CGFloat,
        desiredScale: CGFloat,
        minimumScale: CGFloat,
        meldGap: CGFloat
    ) {
        let availableWidth = max(0, bounds.upperBound - bounds.lowerBound)
        if Self.meldRowWidth(
            cardCounts: melds.map(\.cards.count),
            scale: desiredScale,
            cardStepFraction: Self.meldCardStepFraction,
            meldGap: meldGap
        ) <= availableWidth {
            drawMeldRow(
                melds,
                bounds: bounds,
                rowY: seatY,
                alignment: alignment,
                scale: desiredScale,
                cardStepFraction: Self.meldCardStepFraction,
                meldGap: meldGap
            )
            return
        }

        if usesExpandedIPadLayout {
            let preferredRows = greedyMeldRows(
                melds,
                scale: desiredScale,
                meldGap: meldGap,
                availableWidth: availableWidth
            )
            if preferredRows.count <= 2 {
                let rowYs = sideMeldRowYs(
                    rowCount: preferredRows.count,
                    seatY: seatY,
                    cardScale: desiredScale
                )
                for (index, row) in preferredRows.enumerated() {
                    drawFittedMeldRow(
                        row,
                        bounds: bounds,
                        rowY: rowYs[index],
                        alignment: alignment,
                        desiredScale: desiredScale,
                        minimumScale: minimumScale,
                        meldGap: meldGap
                    )
                }
                return
            }
        }

        if Self.meldRowWidth(
            cardCounts: melds.map(\.cards.count),
            scale: minimumScale,
            cardStepFraction: Self.minimumMeldStepFraction,
            meldGap: meldGap
        ) <= availableWidth {
            drawFittedMeldRow(
                melds,
                bounds: bounds,
                rowY: seatY,
                alignment: alignment,
                desiredScale: minimumScale,
                minimumScale: minimumScale,
                meldGap: meldGap
            )
            return
        }

        var rows = greedyMeldRows(
            melds,
            scale: minimumScale,
            meldGap: meldGap,
            availableWidth: availableWidth
        )
        if rows.count > 2 {
            rows = balancedMeldGroups(melds, groupCount: 2)
        }

        let rowYs = sideMeldRowYs(
            rowCount: rows.count,
            seatY: seatY,
            cardScale: minimumScale
        )
        for (index, row) in rows.enumerated() {
            drawFittedMeldRow(
                row,
                bounds: bounds,
                rowY: rowYs[index],
                alignment: alignment,
                desiredScale: minimumScale,
                minimumScale: minimumScale,
                meldGap: meldGap
            )
        }
    }

    private func sideMeldRowYs(
        rowCount: Int,
        seatY: CGFloat,
        cardScale: CGFloat
    ) -> [CGFloat] {
        guard rowCount > 1 else { return [seatY] }

        let cardHeight = CardNode.size.height * cardScale
        let reservedOwnMeldScale = preferredOwnMeldScaleForLayout
        let ownMeldTop = ownMeldRowY(scale: reservedOwnMeldScale)
            + CardNode.size.height * reservedOwnMeldScale / 2
        let minimumCenter = ownMeldTop + cardHeight / 2 + 2
        var spacing = cardHeight + 10
        var maximumCenter = CGFloat.greatestFiniteMagnitude
        if vm.state.players.count >= 5 {
            let topSeatY = size.height - 24 - 60
            let topCornerScale = preferredOpponentMeldScaleForLayout
            let topCornerRowY = Self.topCornerMeldRowY(
                sceneSize: size,
                seatY: topSeatY,
                horizontalEdgeInset: horizontalEdgeInset,
                playerCount: vm.state.players.count,
                cornerMeldScale: topCornerScale,
                centerMeldScale: topCornerScale
            )
            let topCornerMeldBottom = topCornerRowY
                - CardNode.size.height * topCornerScale / 2
            maximumCenter = topCornerMeldBottom - cardHeight / 2 - 2
            spacing = min(spacing, max(0, maximumCenter - minimumCenter))
        }

        let preferredMidpoint = seatY + 2
        let minimumMidpoint = minimumCenter + spacing / 2
        let maximumMidpoint = maximumCenter - spacing / 2
        let midpoint = min(
            max(preferredMidpoint, minimumMidpoint),
            maximumMidpoint
        )
        return [midpoint - spacing / 2, midpoint + spacing / 2]
    }

    private func drawCenterTopMeldWings(
        _ melds: [Meld],
        seatY: CGFloat,
        desiredScale: CGFloat,
        minimumScale: CGFloat,
        meldGap: CGFloat
    ) {
        let seatHalfWidth = opponentSeatWidth / 2
        let seatPadding: CGFloat = 6
        let outerSeatX = max(
            size.width * SeatLayout.topCornerXFraction,
            seatLayoutHorizontalInset + 60
        )
        let centerX = size.width / 2
        let leftBounds = (outerSeatX + seatHalfWidth + seatPadding)...(
            centerX - seatHalfWidth - seatPadding
        )
        let rightBounds = (centerX + seatHalfWidth + seatPadding)...(
            size.width - outerSeatX - seatHalfWidth - seatPadding
        )
        let groups = balancedMeldGroups(melds, groupCount: 2)
        let rowY = Self.centerTopMeldRowY(
            sceneSize: size,
            seatY: seatY,
            horizontalEdgeInset: horizontalEdgeInset,
            meldScale: desiredScale
        )

        if let left = groups.first, !left.isEmpty {
            drawFittedMeldRow(
                left,
                bounds: leftBounds,
                rowY: rowY,
                alignment: .center,
                desiredScale: desiredScale,
                minimumScale: minimumScale,
                meldGap: meldGap
            )
        }
        if groups.count > 1, !groups[1].isEmpty {
            drawFittedMeldRow(
                groups[1],
                bounds: rightBounds,
                rowY: rowY,
                alignment: .center,
                desiredScale: desiredScale,
                minimumScale: minimumScale,
                meldGap: meldGap
            )
        }
    }

    private func drawFittedMeldRow(
        _ melds: [Meld],
        bounds: ClosedRange<CGFloat>,
        rowY: CGFloat,
        alignment: MeldRowAlignment,
        desiredScale: CGFloat,
        minimumScale: CGFloat,
        meldGap: CGFloat
    ) {
        let availableWidth = max(0, bounds.upperBound - bounds.lowerBound)
        let scale = fittedScale(
            for: melds,
            desiredScale: desiredScale,
            minimumScale: minimumScale,
            meldGap: meldGap,
            availableWidth: availableWidth
        )
        let stepFraction = Self.fittedMeldStepFraction(
            cardCounts: melds.map(\.cards.count),
            scale: scale,
            desiredStepFraction: Self.meldCardStepFraction,
            meldGap: meldGap,
            availableWidth: availableWidth
        )
        drawMeldRow(
            melds,
            bounds: bounds,
            rowY: rowY,
            alignment: alignment,
            scale: scale,
            cardStepFraction: stepFraction,
            meldGap: meldGap
        )
    }

    private func drawMeldRow(
        _ melds: [Meld],
        bounds: ClosedRange<CGFloat>,
        rowY: CGFloat,
        alignment: MeldRowAlignment,
        scale: CGFloat,
        cardStepFraction: CGFloat,
        meldGap: CGFloat
    ) {
        let cardW = CardNode.size.width * scale
        let cardH = CardNode.size.height * scale
        let cardStep = cardW * cardStepFraction
        let widths = melds.map {
            CGFloat(max(0, $0.cards.count - 1)) * cardStep + cardW
        }
        let totalWidth = widths.reduce(0, +)
            + CGFloat(max(0, melds.count - 1)) * meldGap
        let availableVisualWidth = max(
            0,
            bounds.upperBound - bounds.lowerBound - 14
        )
        let x: CGFloat
        switch alignment {
        case .leading:
            x = bounds.lowerBound + 7
        case .center:
            x = bounds.lowerBound + 7
                + max(0, availableVisualWidth - totalWidth) / 2
        case .trailing:
            x = bounds.upperBound - 7 - totalWidth
        }
        var meldX = x

        for (meldIndex, meld) in melds.enumerated() {
            let width = widths[meldIndex]
            addMeldTarget(
                for: meld,
                rect: CGRect(
                    x: meldX - 7,
                    y: rowY - cardH / 2 - 5,
                    width: width + 14,
                    height: cardH + 10
                )
            )
            for (cardIndex, card) in meld.cards.enumerated() {
                let node = CardNode(card: card, faceUp: true, theme: theme)
                node.setScale(scale)
                let position = CGPoint(
                    x: meldX + CGFloat(cardIndex) * cardStep + cardW / 2,
                    y: rowY
                )
                if cardIndex == 0 {
                    attachShadow(to: node, at: position, scale: scale)
                }
                node.position = position
                node.zPosition = 3 + CGFloat(cardIndex) * 0.01
                node.name = "meld:\(meld.id.uuidString)"
                prepareMeldCardNode(node, card: card, in: meld)
                meldsLayer.addChild(node)
            }
            meldX += width + meldGap
        }
    }

    private func greedyMeldRows(
        _ melds: [Meld],
        scale: CGFloat,
        meldGap: CGFloat,
        availableWidth: CGFloat
    ) -> [[Meld]] {
        Self.greedyMeldRowIndices(
            cardCounts: melds.map(\.cards.count),
            scale: scale,
            meldGap: meldGap,
            availableWidth: availableWidth
        ).map { indices in
            indices.map { melds[$0] }
        }
    }

    static func greedyMeldRowIndices(
        cardCounts: [Int],
        scale: CGFloat,
        meldGap: CGFloat,
        availableWidth: CGFloat
    ) -> [[Int]] {
        var rows: [[Int]] = []
        for index in cardCounts.indices {
            guard var row = rows.popLast() else {
                rows.append([index])
                continue
            }
            let candidate = row + [index]
            if meldRowWidth(
                cardCounts: candidate.map { cardCounts[$0] },
                scale: scale,
                cardStepFraction: meldCardStepFraction,
                meldGap: meldGap
            ) <= availableWidth {
                row.append(index)
                rows.append(row)
            } else {
                rows.append(row)
                rows.append([index])
            }
        }
        return rows
    }

    private func balancedMeldGroups(
        _ melds: [Meld],
        groupCount: Int
    ) -> [[Meld]] {
        let count = min(max(1, groupCount), max(1, melds.count))
        var groups = Array(repeating: [Meld](), count: count)
        var weights = Array(repeating: CGFloat.zero, count: count)
        for meld in melds {
            let targetIndex = weights.enumerated().min {
                $0.element < $1.element
            }?.offset ?? 0
            groups[targetIndex].append(meld)
            weights[targetIndex] += CGFloat(max(1, meld.cards.count))
        }
        return groups
    }

    private func fittedScale(
        for melds: [Meld],
        desiredScale: CGFloat,
        minimumScale: CGFloat,
        meldGap: CGFloat,
        availableWidth: CGFloat
    ) -> CGFloat {
        max(
            minimumScale,
            Self.fittedMeldScale(
                cardCounts: melds.map(\.cards.count),
                desiredScale: desiredScale,
                meldGap: meldGap,
                availableWidth: availableWidth
            )
        )
    }

    static func fittedMeldScale(
        cardCounts: [Int],
        desiredScale: CGFloat,
        meldGap: CGFloat,
        availableWidth: CGFloat
    ) -> CGFloat {
        let targetPadding: CGFloat = 14
        let totalGap = CGFloat(max(0, cardCounts.count - 1)) * meldGap
        let unscaledCardWidth = cardCounts.reduce(CGFloat.zero) { total, count in
            let steps = CGFloat(max(0, count - 1))
            return total + CardNode.size.width * (
                1 + steps * Self.meldCardStepFraction
            )
        }
        guard unscaledCardWidth > 0 else { return desiredScale }

        let fittedScale = max(
            0,
            availableWidth - targetPadding - totalGap
        ) / unscaledCardWidth
        return min(desiredScale, fittedScale)
    }

    static func fittedMeldStepFraction(
        cardCounts: [Int],
        scale: CGFloat,
        desiredStepFraction: CGFloat,
        meldGap: CGFloat,
        availableWidth: CGFloat,
        targetPadding: CGFloat = 14
    ) -> CGFloat {
        let cardWidth = CardNode.size.width * scale
        let fixedWidth = CGFloat(cardCounts.count) * cardWidth
            + CGFloat(max(0, cardCounts.count - 1)) * meldGap
            + targetPadding
        let totalSteps = CGFloat(
            cardCounts.reduce(0) { $0 + max(0, $1 - 1) }
        )
        guard totalSteps > 0 else { return desiredStepFraction }
        let fittedStep = max(0, availableWidth - fixedWidth)
            / (totalSteps * cardWidth)
        return max(
            Self.minimumMeldStepFraction,
            min(desiredStepFraction, fittedStep)
        )
    }

    static func meldRowWidth(
        cardCounts: [Int],
        scale: CGFloat,
        cardStepFraction: CGFloat,
        meldGap: CGFloat
    ) -> CGFloat {
        let cardWidth = CardNode.size.width * scale
        let cardsWidth = cardCounts.reduce(CGFloat.zero) { total, count in
            total + cardWidth * (
                1 + CGFloat(max(0, count - 1)) * cardStepFraction
            )
        }
        return cardsWidth
            + CGFloat(max(0, cardCounts.count - 1)) * meldGap
            + 14
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
        let target = SKShapeNode(rect: rect, cornerRadius: 10)
        target.fillColor = theme.contractPillBg.withAlphaComponent(0.40)
        target.strokeColor = acceptsCard
            ? UIColor(red: 0.38, green: 0.86, blue: 0.66, alpha: 0.62)
            : theme.feltStroke.withAlphaComponent(0.58)
        target.lineWidth = acceptsCard ? 1.8 : 1.2
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
        let usesRoomyLayout = usesExpandedIPadLayout
        let panelSize = CGSize(
            width: currentPlayerHUDWidth,
            height: usesRoomyLayout ? 76 : 62
        )
        let center = CGPoint(x: horizontalEdgeInset + panelSize.width / 2,
                             y: stagingTrayY + 8)
        let panel = SKShapeNode(
            rectOf: panelSize,
            cornerRadius: panelSize.height / 2
        )
        if isActive {
            addActiveTurnHalo(at: center, size: panelSize, to: seatsLayer)
        }
        panel.fillColor = isActive ? theme.seatBgCurrent : theme.seatBgOther
        panel.strokeColor = isActive
            ? theme.turnGlow.withAlphaComponent(0.85)
            : theme.feltStroke.withAlphaComponent(0.7)
        panel.lineWidth = isActive ? 3 : 1
        panel.position = center
        panel.zPosition = 2
        seatsLayer.addChild(panel)

        let avatarRadius: CGFloat = usesRoomyLayout ? 17 : 15
        let avatarPosition = CGPoint(x: center.x - panelSize.width / 2 + 24,
                                     y: center.y + 3)
        let avatarColor = theme.avatarColors[colorIndex % theme.avatarColors.count]
        let avatar = SKShapeNode(circleOfRadius: avatarRadius)
        avatar.fillColor = avatarColor
        avatar.strokeColor = isActive
            ? theme.turnGlow
            : UIColor.white.withAlphaComponent(0.8)
        avatar.lineWidth = isActive ? 2.5 : 1
        avatar.position = avatarPosition
        avatar.zPosition = 3
        seatsLayer.addChild(avatar)
        let initial = SKLabelNode(text: String(player.name.prefix(1)).uppercased())
        initial.fontName = theme.titleFont
        initial.fontSize = usesRoomyLayout ? 17 : 15
        initial.fontColor = .white
        initial.horizontalAlignmentMode = .center
        initial.verticalAlignmentMode = .center
        initial.position = avatarPosition
        initial.zPosition = 4
        seatsLayer.addChild(initial)

        let textX = avatarPosition.x + avatarRadius + 8
        let name = SKLabelNode(text: player.name)
        name.fontName = theme.titleFont
        name.fontSize = usesRoomyLayout ? 15 : 13
        name.fontColor = isActive ? theme.turnGlow : theme.seatTitle
        name.horizontalAlignmentMode = .left
        name.verticalAlignmentMode = .center
        let topLineY = center.y + (usesRoomyLayout ? 20 : 16)
        name.position = CGPoint(x: textX, y: topLineY)
        name.zPosition = 3
        seatsLayer.addChild(name)

        let score = SKLabelNode(text: "\(player.totalScore) pts")
        score.fontName = theme.titleFont
        score.fontSize = usesRoomyLayout ? 11.5 : 9.5
        score.fontColor = isActive ? theme.turnGlow : theme.seatTitle
        score.horizontalAlignmentMode = .right
        score.verticalAlignmentMode = .center
        score.position = CGPoint(
            x: center.x + panelSize.width / 2 - 12,
            y: topLineY
        )
        score.zPosition = 3
        seatsLayer.addChild(score)

        let contract = vm.contractDescription(for: player.id)
        let detail = SKLabelNode(
            text: "LV \(player.currentLevel)  •  \(contract)"
        )
        detail.fontName = theme.titleFont
        detail.fontSize = usesRoomyLayout ? 11.5 : 9.5
        detail.fontColor = isActive ? theme.turnGlow : theme.contractPillText
        detail.horizontalAlignmentMode = .left
        detail.verticalAlignmentMode = .center
        detail.position = CGPoint(
            x: textX,
            y: center.y + (usesRoomyLayout ? 1 : 0)
        )
        detail.zPosition = 3
        seatsLayer.addChild(detail)

        let buysRemaining = vm.buysRemaining(for: player.id)
        let counterSize = CGSize(width: 94, height: 20)
        let counterCenter = CGPoint(
            x: center.x + panelSize.width / 2 - counterSize.width / 2 - 10,
            y: center.y - (usesRoomyLayout ? 24 : 20)
        )
        let counter = SKShapeNode(
            rectOf: counterSize,
            cornerRadius: counterSize.height / 2
        )
        counter.fillColor = buysRemaining > 0
            ? theme.contractPillBg
            : theme.scoreChipBg
        counter.strokeColor = buysRemaining > 0
            ? theme.turnGlow.withAlphaComponent(0.9)
            : theme.feltStroke.withAlphaComponent(0.8)
        counter.lineWidth = 1.5
        counter.position = counterCenter
        counter.zPosition = 3
        seatsLayer.addChild(counter)

        let buysLabel = SKLabelNode(text: "BUYS LEFT")
        buysLabel.fontName = theme.titleFont
        buysLabel.fontSize = usesRoomyLayout ? 9 : 7.5
        buysLabel.fontColor = buysRemaining > 0
            ? theme.contractPillText
            : theme.scoreChipText
        buysLabel.horizontalAlignmentMode = .center
        buysLabel.verticalAlignmentMode = .center
        buysLabel.position = CGPoint(
            x: counterCenter.x - 13,
            y: counterCenter.y
        )
        buysLabel.zPosition = 4
        seatsLayer.addChild(buysLabel)

        let buysCount = SKLabelNode(text: "\(buysRemaining)")
        buysCount.fontName = theme.titleFont
        buysCount.fontSize = usesRoomyLayout ? 14 : 13
        buysCount.fontColor = buysRemaining > 0
            ? theme.turnGlow
            : theme.scoreChipText
        buysCount.horizontalAlignmentMode = .center
        buysCount.verticalAlignmentMode = .center
        buysCount.position = CGPoint(
            x: counterCenter.x + 34,
            y: counterCenter.y
        )
        buysCount.zPosition = 4
        seatsLayer.addChild(buysCount)
    }

    private func buildHand() {
        handLayer.removeAllChildren()
        handSlots.removeAll()
        let hand = vm.unstagedCards
        let ownerId = vm.currentPlayer.id
        let currentIds = Set(vm.currentPlayer.hand.map(\.id))
        let highlightedIds = vm.state.highlightedCardIds(for: ownerId)
        let newlyDrawnIds = lastRenderedHandOwnerId == ownerId
            ? currentIds.subtracting(lastRenderedHandIds)
            : []
        lastRenderedHandOwnerId = ownerId
        lastRenderedHandIds = currentIds
        guard !hand.isEmpty else { return }

        let cardSize = scaledHandCardSize
        let cardWidth = cardSize.width
        let availableWidth = size.width - horizontalEdgeInset * 2 - 8
        let step: CGFloat
        if hand.count == 1 {
            step = 0
        } else {
            step = min(cardWidth + 8,
                       max(25, (availableWidth - cardWidth) / CGFloat(hand.count - 1)))
        }
        let totalWidth = cardWidth + CGFloat(hand.count - 1) * step
        let startX = (size.width - totalWidth) / 2 + cardWidth / 2
        let baseY: CGFloat = handRowY
        let maxLift: CGFloat = 8
        let maxAngle: CGFloat = 0.035

        for (i, card) in hand.enumerated() {
            let node = CardNode(card: card, faceUp: true, theme: theme)
            node.name = "card:\(card.id.uuidString)"
            node.setScale(handCardScale)
            let centeredIdx = CGFloat(i) - CGFloat(hand.count - 1) / 2
            let norm = centeredIdx / max(1, CGFloat(hand.count - 1) / 2)
            let lift = maxLift * (1 - norm * norm)
            let x = startX + CGFloat(i) * step
            let isHighlighted = highlightedIds.contains(card.id)
            let y = baseY + lift + (isHighlighted ? 4 : 0)
            let angle = -norm * maxAngle
            let pos = CGPoint(x: x, y: y)
            node.setNewCardHighlighted(
                isHighlighted,
                animateArrival: newlyDrawnIds.contains(card.id)
            )
            node.zPosition = 4 + CGFloat(i) * 0.01
            if newlyDrawnIds.contains(card.id) {
                node.position = SeatLayout.pileCenter(sceneSize: size)
                node.zRotation = 0
                node.setScale(handCardScale * 0.78)
                node.alpha = 0.25
                handLayer.addChild(node)

                let move = SKAction.move(to: pos, duration: 0.24)
                move.timingMode = .easeOut
                let settle = SKAction.group([
                    move,
                    .rotate(toAngle: angle, duration: 0.24,
                            shortestUnitArc: true),
                    .scale(to: handCardScale, duration: 0.24),
                    .fadeAlpha(to: 1.0, duration: 0.16),
                ])
                node.run(settle) { [weak self, weak node] in
                    guard let self, let node else { return }
                    self.attachShadow(
                        to: node,
                        at: pos,
                        rotation: angle,
                        scale: self.handCardScale
                    )
                }
            } else {
                attachShadow(
                    to: node,
                    at: pos,
                    rotation: angle,
                    scale: handCardScale
                )
                node.position = pos
                node.zRotation = angle
                handLayer.addChild(node)
            }
            handSlots.append((id: card.id, x: x, y: y))
        }
    }

    // MARK: - Layout constants

    private static let pileScale: CGFloat = 0.90
    private static let pileGap: CGFloat = 34
    static let expandedIPadLayoutMinimumHeight: CGFloat = 600
    static let compactOpponentMeldScale: CGFloat = 0.62
    static let expandedOpponentMeldScale: CGFloat = 0.78
    static let compactOwnMeldScale: CGFloat = 0.68
    static let expandedOwnMeldScale: CGFloat = 0.86
    static let minimumMeldScale: CGFloat = 0.34
    static let ownMeldGap: CGFloat = 14
    static let ownMeldHandGap: CGFloat = 12
    static let standardOpponentMeldGap: CGFloat = 12
    static let crowdedOpponentMeldGap: CGFloat = 8
    static let meldCardStepFraction: CGFloat = 0.50
    static let minimumMeldStepFraction: CGFloat = 0.25
    static let compactStagingTrayHeight: CGFloat = 56
    static let expandedStagingTrayHeight: CGFloat = 112
    static let stagingTrayHandGap: CGFloat = 8
    static let compactStagedCardScale: CGFloat = 0.44
    static let expandedStagedCardScale: CGFloat = 0.76
    static let turnBannerHeight: CGFloat = 48
    static let turnBannerTopInset: CGFloat = 7
    static let topMeldBannerGap: CGFloat = 8
    static let topMeldLaneGap: CGFloat = 12

    static func usesExpandedIPadLayout(sceneHeight: CGFloat) -> Bool {
        sceneHeight >= expandedIPadLayoutMinimumHeight
    }

    static func preferredOpponentMeldScale(sceneHeight: CGFloat) -> CGFloat {
        usesExpandedIPadLayout(sceneHeight: sceneHeight)
            ? expandedOpponentMeldScale
            : compactOpponentMeldScale
    }

    static func preferredOwnMeldScale(sceneHeight: CGFloat) -> CGFloat {
        usesExpandedIPadLayout(sceneHeight: sceneHeight)
            ? expandedOwnMeldScale
            : compactOwnMeldScale
    }

    static func stagingTrayHeight(sceneHeight: CGFloat) -> CGFloat {
        usesExpandedIPadLayout(sceneHeight: sceneHeight)
            ? expandedStagingTrayHeight
            : compactStagingTrayHeight
    }

    static func stagedCardScale(sceneHeight: CGFloat) -> CGFloat {
        usesExpandedIPadLayout(sceneHeight: sceneHeight)
            ? expandedStagedCardScale
            : compactStagedCardScale
    }

    private static var protectedPileCorridorHalfWidth: CGFloat {
        (
            CardNode.size.width * pileScale
                + pileGap
                + pileZoneSize.width
        ) / 2 + 6
    }
    private static var pileZoneSize: CGSize {
        CGSize(
            width: CardNode.size.width * pileScale + 24,
            height: CardNode.size.height * pileScale + 12
        )
    }

    private var hasUsableLayoutSize: Bool {
        // SwiftUI creates the scene at 1x1 before GeometryReader supplies
        // landscape bounds; closed meld lanes are invalid at that placeholder.
        let sideSeatCenterInset = seatLayoutHorizontalInset + 60
        let sideMeldStart = sideSeatCenterInset + opponentSeatWidth / 2 + 6
        let sideMeldEnd = size.width / 2
            - Self.protectedPileCorridorHalfWidth
        return sideMeldStart <= sideMeldEnd
            && size.height >= CardNode.size.height * 2.5
    }

    private var usesExpandedIPadLayout: Bool {
        Self.usesExpandedIPadLayout(sceneHeight: size.height)
    }

    private var preferredOpponentMeldScaleForLayout: CGFloat {
        Self.preferredOpponentMeldScale(sceneHeight: size.height)
    }

    private var preferredOwnMeldScaleForLayout: CGFloat {
        Self.preferredOwnMeldScale(sceneHeight: size.height)
    }

    private var currentStagingTrayHeight: CGFloat {
        Self.stagingTrayHeight(sceneHeight: size.height)
    }

    private var stagedCardScaleForLayout: CGFloat {
        Self.stagedCardScale(sceneHeight: size.height)
    }

    private var handCardScale: CGFloat {
        size.height < 500 ? 0.84 : 1
    }

    private var opponentSeatWidth: CGFloat {
        Self.opponentSeatWidth(
            sceneWidth: size.width,
            playerCount: vm.state.players.count
        )
    }

    static func opponentSeatWidth(
        sceneWidth: CGFloat,
        playerCount: Int
    ) -> CGFloat {
        if sceneWidth < 720 {
            return 64
        }
        return playerCount >= 5 ? 112 : 138
    }

    static func turnBannerWidth(
        sceneWidth: CGFloat,
        horizontalEdgeInset: CGFloat
    ) -> CGFloat {
        min(
            520,
            max(300, sceneWidth - horizontalEdgeInset * 2 - 304)
        )
    }

    static func turnBannerFrame(
        sceneSize: CGSize,
        horizontalEdgeInset: CGFloat
    ) -> CGRect {
        let width = turnBannerWidth(
            sceneWidth: sceneSize.width,
            horizontalEdgeInset: horizontalEdgeInset
        )
        return CGRect(
            x: sceneSize.width / 2 - width / 2,
            y: sceneSize.height - turnBannerTopInset - turnBannerHeight,
            width: width,
            height: turnBannerHeight
        )
    }

    static func centerTopMeldRowY(
        sceneSize: CGSize,
        seatY: CGFloat,
        horizontalEdgeInset: CGFloat,
        meldScale: CGFloat
    ) -> CGFloat {
        let bannerBottom = turnBannerFrame(
            sceneSize: sceneSize,
            horizontalEdgeInset: horizontalEdgeInset
        ).minY
        let highestSafeCenter = bannerBottom
            - topMeldBannerGap
            - CardNode.size.height * meldScale / 2
        return min(seatY, highestSafeCenter)
    }

    static func topCornerMeldRowY(
        sceneSize: CGSize,
        seatY: CGFloat,
        horizontalEdgeInset: CGFloat,
        playerCount: Int,
        cornerMeldScale: CGFloat,
        centerMeldScale: CGFloat
    ) -> CGFloat {
        let cornerCardHalfHeight = CardNode.size.height
            * cornerMeldScale / 2
        let rowBelowSeat = seatY - 21 - 6 - cornerCardHalfHeight
        guard playerCount >= 6 else { return rowBelowSeat }

        let centerRowY = centerTopMeldRowY(
            sceneSize: sceneSize,
            seatY: seatY,
            horizontalEdgeInset: horizontalEdgeInset,
            meldScale: centerMeldScale
        )
        let centerMeldBottom = centerRowY
            - CardNode.size.height * centerMeldScale / 2
        let rowBelowCenterMelds = centerMeldBottom
            - topMeldLaneGap
            - cornerCardHalfHeight
        return min(rowBelowSeat, rowBelowCenterMelds)
    }

    private var scaledHandCardSize: CGSize {
        CGSize(
            width: CardNode.size.width * handCardScale,
            height: CardNode.size.height * handCardScale
        )
    }

    private var handRowY: CGFloat {
        max(scaledHandCardSize.height / 2 + 18, size.height * 0.15)
    }

    private var horizontalEdgeInset: CGFloat {
        Self.tableHorizontalEdgeInset(
            sceneWidth: size.width,
            safeAreaInsets: tableSafeAreaInsets
        )
    }

    private var seatLayoutHorizontalInset: CGFloat {
        Self.seatLayoutHorizontalInset(for: tableSafeAreaInsets)
    }

    static func tableHorizontalEdgeInset(
        sceneWidth: CGFloat,
        safeAreaInsets: UIEdgeInsets
    ) -> CGFloat {
        let baseInset: CGFloat = sceneWidth >= 780 ? 54 : 24
        let cutoutInset = max(safeAreaInsets.left, safeAreaInsets.right)
        return max(baseInset, cutoutInset + 8)
    }

    static func seatLayoutHorizontalInset(
        for safeAreaInsets: UIEdgeInsets
    ) -> CGFloat {
        let cutoutInset = max(safeAreaInsets.left, safeAreaInsets.right)
        // SeatLayout adds 60 pt to this value; 15 keeps a 138 pt pill
        // six points inside the device's protected edge.
        return max(24, cutoutInset + 15)
    }

    private var currentPlayerHUDWidth: CGFloat {
        size.width < 720 ? 190 : 240
    }

    private var stagingTrayY: CGFloat {
        Self.stagingTrayY(
            handRowY: handRowY,
            handCardHeight: scaledHandCardSize.height,
            sceneHeight: size.height
        )
    }

    static func stagingTrayY(
        handRowY: CGFloat,
        handCardHeight: CGFloat,
        sceneHeight: CGFloat
    ) -> CGFloat {
        handRowY
            + handCardHeight / 2
            + stagingTrayHandGap
            + stagingTrayHeight(sceneHeight: sceneHeight) / 2
    }

    private var stagingTrayRect: CGRect {
        let left = horizontalEdgeInset + currentPlayerHUDWidth + 12
        let right = size.width - horizontalEdgeInset - 176
        let width = max(210, right - left)
        return CGRect(
            x: left,
            y: stagingTrayY - currentStagingTrayHeight / 2,
            width: width,
            height: currentStagingTrayHeight
        )
    }

    private var tableauLaneY: CGFloat { stagingTrayY }

    private func ownMeldRowY(scale: CGFloat) -> CGFloat {
        Self.ownMeldRowY(
            handRowY: handRowY,
            handCardHeight: scaledHandCardSize.height,
            meldScale: scale
        )
    }

    static func ownMeldRowY(
        handRowY: CGFloat,
        handCardHeight: CGFloat,
        meldScale: CGFloat
    ) -> CGFloat {
        handRowY
            + handCardHeight / 2
            + Self.ownMeldHandGap
            + CardNode.size.height * meldScale / 2
    }

    private func ownMeldScale(for melds: [Meld], meldGap: CGFloat) -> CGFloat {
        let desiredScale = preferredOwnMeldScaleForLayout
        let widthAtScaleOne = melds.reduce(CGFloat.zero) { total, meld in
            total + CardNode.size.width * (
                1 + CGFloat(max(0, meld.cards.count - 1))
                    * Self.meldCardStepFraction
            )
        }
        let totalGaps = CGFloat(max(0, melds.count - 1)) * meldGap
        let available = max(1, stagingTrayRect.width - 16 - totalGaps)
        guard widthAtScaleOne > 0 else { return desiredScale }
        return min(
            desiredScale,
            max(Self.minimumMeldScale, available / widthAtScaleOne)
        )
    }

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
        let scale = stagedCardScaleForLayout
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
        guard vm.state.phase == .awaitingDraw
                || vm.state.phase == .awaitingMeldOrDiscard else {
            return
        }

        let controlSize = CGSize(width: 44, height: 42)
        let controlGap: CGFloat = 4
        let suitControlX = size.width
            - horizontalEdgeInset
            - controlSize.width / 2
        let rankControlX = suitControlX - controlSize.width - controlGap
        let scoreControlX = rankControlX - controlSize.width - controlGap
        addSmallControl(
            title: "SCORE",
            name: "show-score",
            at: CGPoint(
                x: scoreControlX,
                y: size.height - 31
            ),
            size: controlSize,
            to: actionLayer
        )

        guard !vm.isCurrentPlayerCPU || vm.isOnlineGame else { return }

        if !vm.isBuyDecisionActive {
            let action = contextAction
            if Self.shouldDisplayContextAction(
                name: action.name,
                enabled: action.enabled
            ) {
                addActionButton(title: action.title, name: action.name,
                                enabled: action.enabled,
                                emphasized: action.emphasized)
            }
        }

        addSmallControl(
            title: "RANK",
            name: "sort-rank",
            at: CGPoint(
                x: rankControlX,
                y: size.height - 31
            ),
            size: controlSize,
            to: actionLayer
        )
        addSmallControl(
            title: "SUIT",
            name: "sort-suit",
            at: CGPoint(
                x: suitControlX,
                y: size.height - 31
            ),
            size: controlSize,
            to: actionLayer
        )
    }

    private var contextAction: (title: String, name: String?, enabled: Bool,
                                emphasized: Bool) {
        switch vm.state.phase {
        case .awaitingDraw:
            return ("PURCHASE ROUND", nil, false, false)
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
                return ("PUT DOWN CONTRACT", "go-down", true, true)
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

    static func shouldDisplayContextAction(
        name: String?,
        enabled: Bool
    ) -> Bool {
        name != nil && enabled
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
        button.fillColor = theme.scoreChipBg
        button.strokeColor = theme.turnGlow.withAlphaComponent(0.78)
        button.lineWidth = 1.5
        button.position = position
        button.zPosition = 25
        button.name = name
        layer.addChild(button)

        let label = SKLabelNode(text: title)
        label.fontName = theme.titleFont
        label.fontSize = controlSize.height < 30 ? 8 : 10
        label.fontColor = theme.bannerText
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
            let count = Self.cardCountLabel(vm.stagedCards.count).uppercased()
            return "VALID \(type)  •  \(count)"
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

        if let name = interactiveName(at: point) {
            if vm.isBuyDecisionActive {
                if Self.isSafeUtilityControlDuringBuyDecision(name),
                   handleImmediateControl(name) {
                    return
                }
            } else if handleImmediateControl(name) {
                return
            }
        }

        if let uuid = Self.handCardId(
            at: point,
            slots: handSlots,
            cardSize: scaledHandCardSize
        ), let hit = handLayer.children.first(where: {
            $0.name == "card:\(uuid.uuidString)"
        }) as? CardNode {
            beginDrag(card: hit, id: uuid, touchPoint: point)
            return
        }

        guard !vm.isBuyDecisionActive else { return }

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
            beginDrag(card: hit, id: uuid, touchPoint: point)
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
            if dragAllowsGameplay,
               vm.isLocalPlayersTurn,
               vm.state.phase == .awaitingMeldOrDiscard {
                switch cardDropTarget(at: point, for: card) {
                case .some(.discard):
                    guard let node = draggingCard else { return }
                    guard vm.requestDiscard(card) else {
                        cancelDrag()
                        return
                    }
                    animateDiscard(card, node: node)
                    return
                case .some(.meld(let meldId)):
                    if vm.playHandCard(card, to: meldId) {
                        successFeedback()
                        completeDrag()
                    } else {
                        warningFeedback()
                        cancelDrag()
                    }
                    return
                case .none:
                    break
                }
            }

            if dragAllowsGameplay,
               vm.isLocalPlayersTurn,
               vm.state.phase == .awaitingMeldOrDiscard,
               !vm.currentPlayer.hasGoneDownThisRound,
               stagingTrayRect.contains(point) {
                vm.toggleStaged(cardId: id)
                selectionFeedback()
                completeDrag()
                return
            }

            let dx = point.x - dragTouchOrigin.x
            let dy = point.y - dragTouchOrigin.y
            if Self.isCardTap(dx: dx, dy: dy) {
                guard Self.allowsTapToStage(
                    isLocalPlayersTurn: vm.isLocalPlayersTurn,
                    phase: vm.state.phase,
                    isBuyDecisionActive: vm.isBuyDecisionActive,
                    hasGoneDownThisRound:
                        vm.currentPlayer.hasGoneDownThisRound
                ) else {
                    cancelDrag()
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
        case "show-score":
            vm.presentScorecard()
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

    static func isHandSortControl(_ name: String) -> Bool {
        name == "sort-rank" || name == "sort-suit"
    }

    static func isSafeUtilityControlDuringBuyDecision(_ name: String) -> Bool {
        isHandSortControl(name) || name == "show-score"
    }

    static func cardCountLabel(_ count: Int) -> String {
        "\(count) \(count == 1 ? "card" : "cards")"
    }

    static func turnTitle(
        playerName: String,
        isLocalPlayersTurn: Bool,
        isCPU: Bool
    ) -> String {
        if isLocalPlayersTurn && !isCPU {
            return "YOUR TURN"
        }
        return "\(playerName)'s turn".uppercased()
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

    private func cardDropTarget(
        at point: CGPoint,
        for card: Card
    ) -> CardDropTarget? {
        let pointInMeldLayer = meldsLayer.convert(point, from: self)
        let targetFrames = meldTargetNodes.mapValues { $0.frame }
        let eligibleIds = Set(vm.state.melds.compactMap {
            vm.canPlay(card, to: $0) ? $0.id : nil
        })
        let discardFrame = convertedRect(
            discardDropZone(),
            from: self,
            to: meldsLayer
        )
        return Self.preferredCardDropTarget(
            at: pointInMeldLayer,
            discardFrame: discardFrame,
            meldTargetFrames: targetFrames,
            eligibleIds: eligibleIds
        )
    }

    private func convertedRect(
        _ rect: CGRect,
        from source: SKNode,
        to destination: SKNode
    ) -> CGRect {
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
        ].map { source.convert($0, to: destination) }
        let xs = corners.map(\.x)
        let ys = corners.map(\.y)
        return CGRect(
            x: xs.min() ?? 0,
            y: ys.min() ?? 0,
            width: (xs.max() ?? 0) - (xs.min() ?? 0),
            height: (ys.max() ?? 0) - (ys.min() ?? 0)
        )
    }

    static func preferredCardDropTarget(
        at point: CGPoint,
        discardFrame: CGRect,
        meldTargetFrames: [UUID: CGRect],
        eligibleIds: Set<UUID>
    ) -> CardDropTarget? {
        let meldId = meldTargetId(
            at: point,
            targetFrames: meldTargetFrames,
            eligibleIds: eligibleIds
        )
        let isInDiscard = discardFrame.contains(point)
        switch (isInDiscard, meldId) {
        case (false, nil):
            return nil
        case (true, nil):
            return .discard
        case (false, .some(let meldId)):
            return .meld(meldId)
        case (true, .some(let meldId)):
            guard let meldFrame = meldTargetFrames[meldId] else {
                return .discard
            }
            let discardCenter = CGPoint(
                x: discardFrame.midX,
                y: discardFrame.midY
            )
            let meldCenter = CGPoint(
                x: meldFrame.midX,
                y: meldFrame.midY
            )
            let discardDistance = squaredDistance(
                from: point,
                to: discardCenter
            )
            let meldDistance = squaredDistance(from: point, to: meldCenter)
            return meldDistance <= discardDistance
                ? .meld(meldId)
                : .discard
        }
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
        let halfH = scaledHandCardSize.height * 0.75
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

    static func allowsGameplayDrop(
        isLocalPlayersTurn: Bool,
        phase: GameState.Phase,
        isBuyDecisionActive: Bool
    ) -> Bool {
        isLocalPlayersTurn
            && phase == .awaitingMeldOrDiscard
            && !isBuyDecisionActive
    }

    static func allowsTapToStage(
        isLocalPlayersTurn: Bool,
        phase: GameState.Phase,
        isBuyDecisionActive: Bool,
        hasGoneDownThisRound: Bool
    ) -> Bool {
        allowsGameplayDrop(
            isLocalPlayersTurn: isLocalPlayersTurn,
            phase: phase,
            isBuyDecisionActive: isBuyDecisionActive
        ) && !hasGoneDownThisRound
    }

    static func isCardTap(dx: CGFloat, dy: CGFloat) -> Bool {
        let threshold: CGFloat = 18
        return dx * dx + dy * dy <= threshold * threshold
    }

    private func reorderTargetId(forDropX x: CGFloat, draggedId: UUID) -> UUID? {
        let slots = handSlots.filter { $0.id != draggedId }
        for slot in slots where x < slot.x {
            return slot.id
        }
        return nil
    }

    // MARK: - Drag helpers

    private func beginDrag(
        card: CardNode,
        id: UUID,
        touchPoint: CGPoint
    ) {
        draggingCard = card
        draggingCardId = id
        dragOrigin = card.position
        dragOriginRotation = card.zRotation
        dragOriginZ = card.zPosition
        dragOriginScale = card.xScale
        dragTouchOrigin = touchPoint
        dragAllowsGameplay = Self.allowsGameplayDrop(
            isLocalPlayersTurn: vm.isLocalPlayersTurn,
            phase: vm.state.phase,
            isBuyDecisionActive: vm.isBuyDecisionActive
        )
        card.removeAllActions()
        card.zPosition = 500
        card.zRotation = 0
        card.run(SKAction.scale(to: dragOriginScale * 1.08, duration: 0.08))
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
            SKAction.scale(to: dragOriginScale, duration: 0.15)
        ])
        card.run(snap) { [weak self, weak card] in
            card?.zPosition = self?.dragOriginZ ?? 4
        }
        draggingCard = nil
        draggingCardId = nil
        dragTouchOrigin = .zero
        dragAllowsGameplay = false
        clearDragTargets()
    }

    private func completeDrag() {
        draggingCard = nil
        draggingCardId = nil
        dragTouchOrigin = .zero
        dragAllowsGameplay = false
        clearDragTargets()
    }

    private func abandonDragForRebuild() {
        guard draggingCard != nil else { return }
        draggingCard?.removeAllActions()
        draggingCard = nil
        draggingCardId = nil
        dragTouchOrigin = .zero
        dragAllowsGameplay = false
        clearDragTargets()
    }

    private func animateDiscard(_ card: Card, node: CardNode) {
        isAnimatingTurnAction = true
        draggingCard = nil
        draggingCardId = nil
        dragTouchOrigin = .zero
        dragAllowsGameplay = false
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
        Self.discardDropZone(sceneSize: size)
    }

    static func discardDropZone(sceneSize: CGSize) -> CGRect {
        let center = SeatLayout.pileCenter(sceneSize: sceneSize)
        let gap = Self.pileGap
        let pileScale = Self.pileScale
        let pileWidth = CardNode.size.width * pileScale
        let pileHeight = CardNode.size.height * pileScale
        let basePos = CGPoint(x: center.x + pileWidth / 2 + gap / 2,
                              y: center.y)
        let horizontalPad: CGFloat = 12
        let verticalPad: CGFloat = 10
        return CGRect(
            x: basePos.x - pileWidth / 2 - horizontalPad,
            y: basePos.y - pileHeight / 2 - verticalPad,
            width: pileWidth + horizontalPad * 2,
            height: pileHeight + verticalPad * 2
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
