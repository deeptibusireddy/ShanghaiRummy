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
    private let meldButtonLayer = SKNode()
    private let overlayLayer = SKNode()
    private let bannerLabel = SKLabelNode(text: "")

    // Drag-and-drop state (M2d-a).
    private var draggingCard: CardNode?
    private var dragOrigin: CGPoint = .zero
    private var dragOriginRotation: CGFloat = 0
    private var dragOriginZ: CGFloat = 0
    private var draggingCardId: UUID?
    private var discardTargetRing: SKShapeNode?

    /// Slot centers of the current hand fan captured during buildHand().
    /// Used by touchesEnded to compute a reorder target index from the
    /// drop x-position when the user drags a card within the hand row.
    private var handSlots: [(id: UUID, x: CGFloat, y: CGFloat)] = []

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
        addChild(meldButtonLayer)
        addChild(overlayLayer)
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

        // Combined banner: turn + contract, single line at the top edge so
        // opponent seats and shared piles get the full vertical budget.
        bannerLabel.fontName = theme.titleFont
        bannerLabel.fontSize = 14
        bannerLabel.fontColor = theme.bannerText
        bannerLabel.horizontalAlignmentMode = .center
        bannerLabel.verticalAlignmentMode = .top
        bannerLabel.position = CGPoint(x: size.width / 2, y: size.height - 12)
        bannerLabel.zPosition = 5
        addChild(bannerLabel)
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
        let name = vm.currentPlayerName
        let turnPhrase = (name == "You") ? "Your turn" : "\(name)'s turn"
        bannerLabel.text = "\(turnPhrase)  —  Level \(vm.currentPlayer.currentLevel) of \(RulesConfig.maxLevel)  •  \(vm.currentContractDescription)"
        shadowsLayer.removeAllChildren()
        buildPiles()
        buildSeats()
        buildMelds()
        buildHand()
        buildMeldButton()
        buildMeldOverlay()
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
            // Label to the LEFT of the stock so the vertical strip below the
            // piles stays free for the staging tray.
            addPileLabel(at: CGPoint(x: stockPos.x - CardNode.size.width / 2 - 8,
                                     y: stockPos.y),
                         text: "Stock\n\(vm.state.stock.count)",
                         align: .right)
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
            addPileLabel(at: CGPoint(x: basePos.x + CardNode.size.width / 2 + 8,
                                     y: basePos.y),
                         text: "Discard\n\(vm.state.discard.count)",
                         align: .left)
        }
    }

    private func addPileLabel(at position: CGPoint,
                              text: String,
                              align: SKLabelHorizontalAlignmentMode = .center) {
        let l = SKLabelNode(text: text)
        l.fontName = theme.bodyFont
        l.fontSize = 11
        l.fontColor = theme.pileLabel
        l.numberOfLines = 2
        l.horizontalAlignmentMode = align
        l.verticalAlignmentMode = .center
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
            // The bottom seat is "You" — rendered instead as a compact HUD
            // in the bottom-left corner so the middle bottom stays clear for
            // hand + staging tray.
            if seat.edge == .bottom {
                buildYouHUD(player: player, isCurrent: player.id == vm.currentPlayer.id)
                continue
            }
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
            // Bottom seat (current on-device player) — render own melds in a
            // dedicated strip above the hand fan so the player can see what
            // they've laid down and target layoff taps. The strip sits between
            // the You HUD avatar (left) and the Build Meld chip (right), just
            // above the top of the fan.
            if seat.edge == .bottom {
                drawOwnMeldsAboveHand(melds)
                continue
            }
            drawMelds(melds, near: seat)
        }
    }

    /// Renders the current on-device player's own melds in a horizontal
    /// strip above the hand fan. Cards use the same 40% scale as opponent
    /// melds for visual consistency, and lay out left-to-right centered on
    /// the felt so the strip stays clear of the You HUD and Build Meld chip.
    private func drawOwnMeldsAboveHand(_ melds: [Meld]) {
        let scale: CGFloat = 0.40
        let cardW = CardNode.size.width * scale
        let cardH = CardNode.size.height * scale
        let overlap: CGFloat = cardW * 0.42
        let meldGap: CGFloat = 10

        let widths = melds.map { CGFloat($0.cards.count - 1) * overlap + cardW }
        let totalWidth = widths.reduce(0, +) + CGFloat(melds.count - 1) * meldGap

        // Vertical: above the hand fan, aligned with the You HUD row.
        let rowY = handRowY + CardNode.size.height / 2 + 18 + cardH / 2 - 2
        // Horizontal: center on the felt, clamped so it stays clear of the
        // Build Meld chip on the right and the You HUD avatar on the left.
        let leftMargin: CGFloat = 30 + 28 + 6 + 90   // avatar + label estimate
        let rightMargin: CGFloat = 168 + 20 + 10     // chip width + gap
        let minCenter = leftMargin + totalWidth / 2
        let maxCenter = size.width - rightMargin - totalWidth / 2
        // If the strip won't fit, fall back to just centered on the felt.
        let centerX: CGFloat = {
            if minCenter <= maxCenter {
                return min(max(size.width / 2, minCenter), maxCenter)
            }
            return size.width / 2
        }()
        var x = centerX - totalWidth / 2

        // Faint background chip so the strip reads as its own row.
        let padX: CGFloat = 8
        let padY: CGFloat = 4
        let backing = SKShapeNode(
            rect: CGRect(x: x - padX, y: rowY - cardH / 2 - padY,
                         width: totalWidth + padX * 2,
                         height: cardH + padY * 2),
            cornerRadius: 6
        )
        backing.fillColor = theme.contractPillBg.withAlphaComponent(0.35)
        backing.strokeColor = theme.turnGlow.withAlphaComponent(0.25)
        backing.lineWidth = 1
        backing.zPosition = 2
        meldsLayer.addChild(backing)

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

    private func drawMelds(_ melds: [Meld], near seat: SeatLayout.Seat) {
        let scale: CGFloat = 0.40
        let cardW = CardNode.size.width * scale
        let cardH = CardNode.size.height * scale
        let overlap: CGFloat = cardW * 0.42
        let meldGap: CGFloat = 10
        // Height of the seat card visual (must match buildSeats).
        let bgHalfHeight: CGFloat = 52 / 2

        let widths = melds.map { CGFloat($0.cards.count - 1) * overlap + cardW }
        let totalWidth = widths.reduce(0, +) + CGFloat(melds.count - 1) * meldGap

        // Melds always sit BELOW the seat card, in the corridor between the
        // seat card and the shared piles. This keeps each player's melds
        // clearly attached to their own seat and prevents the top-seat melds
        // from bleeding into the stock/discard fan.
        let padding: CGFloat = 6
        let rowY = seat.anchor.y - bgHalfHeight - padding - cardH / 2
        // Clamp x-range to the felt so wide meld rows don't clip the rim.
        let margin: CGFloat = 30
        let minCenter = margin + totalWidth / 2
        let maxCenter = size.width - margin - totalWidth / 2
        let centerX = min(max(seat.anchor.x, minCenter), maxCenter)
        var x = centerX - totalWidth / 2

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

    /// Compact bottom-left HUD standing in for the "You" seat card. Shows
    /// avatar + name + level/score chip + a small horizontal strip of your
    /// own melds (scaled ~35%). Leaves the whole bottom-center clear for the
    /// hand fan and staging tray.
    private func buildYouHUD(player: Player, isCurrent: Bool) {
        // Position above the hand fan (not beside it) so the HUD label never
        // clips or hides behind the leftmost hand cards. Left-aligned to the
        // felt edge, above the fan and below the left-seat meld strip.
        let avatarRadius: CGFloat = 14
        let hudX: CGFloat = 30 + avatarRadius
        let hudY: CGFloat = handRowY + CardNode.size.height / 2 + 18

        if isCurrent {
            let halo = SKShapeNode(circleOfRadius: avatarRadius + 5)
            halo.fillColor = theme.turnGlow.withAlphaComponent(0.35)
            halo.strokeColor = theme.turnGlow
            halo.lineWidth = 2
            halo.glowWidth = 5
            halo.position = CGPoint(x: hudX, y: hudY)
            halo.zPosition = 1
            seatsLayer.addChild(halo)
        }

        let avatarColor = theme.avatarColors[0 % theme.avatarColors.count]
        let avatar = SKShapeNode(circleOfRadius: avatarRadius)
        avatar.fillColor = avatarColor
        avatar.strokeColor = UIColor(white: 1.0, alpha: 0.9)
        avatar.lineWidth = 1.5
        avatar.position = CGPoint(x: hudX, y: hudY)
        avatar.zPosition = 3
        seatsLayer.addChild(avatar)
        let initial = SKLabelNode(text: String(player.name.prefix(1)).uppercased())
        initial.fontName = theme.titleFont
        initial.fontSize = 14
        initial.fontColor = .white
        initial.horizontalAlignmentMode = .center
        initial.verticalAlignmentMode = .center
        initial.position = CGPoint(x: hudX, y: hudY)
        initial.zPosition = 4
        seatsLayer.addChild(initial)

        let ownMeldCount = vm.state.melds.filter { $0.ownerId == player.id }.count
        let meldsFragment = ownMeldCount == 0 ? "" : "  •  \(ownMeldCount) meld\(ownMeldCount == 1 ? "" : "s") down"
        let text = "\(player.name)  Lv \(player.currentLevel)  •  \(player.totalScore) pts\(meldsFragment)"
        let label = SKLabelNode(text: text)
        label.fontName = theme.titleFont
        label.fontSize = 11
        label.fontColor = theme.seatTitle
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: hudX + avatarRadius + 6, y: hudY)
        label.zPosition = 3
        seatsLayer.addChild(label)
    }

    private func buildHand() {
        handLayer.removeAllChildren()
        handSlots.removeAll()
        // On the main table, always show the full hand — staging is a modal
        // concept surfaced through the Build Meld button. Ordered via the
        // VM so the user can reorganize by drag-within-hand-row (M2f).
        let hand = vm.orderedHand
        guard !hand.isEmpty else { return }

        let cardWidth = CardNode.size.width
        let spacing: CGFloat = 8
        let totalWidth = CGFloat(hand.count) * cardWidth + CGFloat(hand.count - 1) * spacing
        let startX = (size.width - totalWidth) / 2 + cardWidth / 2
        let baseY: CGFloat = handRowY
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
            handSlots.append((id: card.id, x: x, y: y))
        }
    }

    // MARK: - Layout constants

    /// Y coordinate for the (unstaged) hand fan. Sits near the bottom edge.
    private var handRowY: CGFloat { max(45, size.height * 0.11) }

    // MARK: - Build Meld button (opens modal overlay, M2d-b)

    /// A prominent chip in the bottom-right that toggles the meld staging
    /// overlay. Visible whenever the current player is a human (i.e. not a
    /// CPU bot) — hot-seat, GameKit, and vs-CPU practice all share the
    /// same on-device player at the bottom seat. Pulses when a valid meld
    /// is staged or the contract is satisfied so the "declare it" moment
    /// is unmissable.
    private func buildMeldButton() {
        meldButtonLayer.removeAllChildren()
        // Only hide the button on CPU turns. In hot-seat and multiplayer,
        // every human seat needs to reach the staging overlay to build,
        // declare, and lay off melds — gating on player name (e.g. == "You")
        // silently broke hot-seat matches whose players are named "Player 1".
        guard !vm.isCurrentPlayerCPU else { return }

        let chipW: CGFloat = 168
        let chipH: CGFloat = 44
        let chipX: CGFloat = size.width - chipW / 2 - 20
        // Sit above the hand fan so it's clearly separated from the cards.
        let chipY: CGFloat = handRowY + CardNode.size.height / 2 + 14
        let chip = SKShapeNode(rectOf: CGSize(width: chipW, height: chipH),
                               cornerRadius: 22)
        chip.fillColor = theme.contractPillBg
        chip.strokeColor = theme.turnGlow
        chip.lineWidth = 2.5
        chip.glowWidth = 2
        chip.position = CGPoint(x: chipX, y: chipY)
        chip.zPosition = 20
        chip.name = "build-meld-button"
        meldButtonLayer.addChild(chip)

        let count = vm.stagedCardIds.count
        let hasGoneDown = vm.currentPlayer.hasGoneDownThisRound
        let label = SKLabelNode(text: buildMeldButtonText(count: count,
                                                          hasGoneDown: hasGoneDown))
        label.fontName = theme.titleFont
        label.fontSize = 15
        label.fontColor = theme.contractPillText
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = chip.position
        label.zPosition = 21
        label.name = "build-meld-button"
        meldButtonLayer.addChild(label)

        // Pulse when there's something meaningful the user could do: a
        // valid staged meld to save, or an already-satisfied contract they
        // could confirm. Draws the eye to the button without being noisy.
        let shouldPulse: Bool = {
            if case .success = vm.stagedValidation { return true }
            if vm.canConfirmGoDown { return true }
            return false
        }()
        if shouldPulse {
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.08, duration: 0.55),
                SKAction.scale(to: 1.0, duration: 0.55)
            ])
            chip.run(SKAction.repeatForever(pulse))
        }
    }

    /// Text shown on the Build Meld chip. Communicates state (staging
    /// count, or "Declare" once ready, or "Lay Off" after go-down).
    private func buildMeldButtonText(count: Int, hasGoneDown: Bool) -> String {
        if hasGoneDown { return "Melds" }
        if vm.canConfirmGoDown { return "Declare Meld!" }
        if count == 0 { return "Build Meld" }
        return "Build Meld (\(count))"
    }

    // MARK: - Meld staging overlay (modal, M2d-b)

    /// Renders a full-screen dimmed panel with staged cards row, hand row,
    /// live validator, and Cancel / Confirm buttons. When open, all touches
    /// on the underlying table are blocked.
    private func buildMeldOverlay() {
        overlayLayer.removeAllChildren()
        guard vm.isMeldOverlayOpen else { return }

        // Dim the underlying scene.
        let dim = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        dim.fillColor = UIColor.black.withAlphaComponent(0.62)
        dim.strokeColor = .clear
        dim.zPosition = 100
        dim.name = "overlay-dim"
        overlayLayer.addChild(dim)

        // Central panel — taller now to fit a "draft" row up top.
        let panelW = min(size.width - 60, 720)
        let panelH = min(size.height - 20, 370)
        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH),
                                cornerRadius: 16)
        panel.fillColor = theme.feltFill
        panel.strokeColor = theme.turnGlow
        panel.lineWidth = 2
        panel.glowWidth = 4
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        panel.zPosition = 101
        panel.name = "overlay-panel"
        overlayLayer.addChild(panel)

        let cx = panel.position.x
        let cy = panel.position.y
        let top = cy + panelH / 2

        // Title.
        let title = SKLabelNode(text: "Build Meld")
        title.fontName = theme.titleFont
        title.fontSize = 18
        title.fontColor = theme.bannerText
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .top
        title.position = CGPoint(x: cx, y: top - 10)
        title.zPosition = 102
        overlayLayer.addChild(title)

        // Progress toward contract (draft-aware).
        let progress = SKLabelNode(text: vm.goDownProgressText)
        progress.fontName = theme.bodyFont
        progress.fontSize = 12
        progress.fontColor = vm.canConfirmGoDown
            ? UIColor(red: 0.55, green: 0.85, blue: 0.55, alpha: 1.0)
            : theme.pileLabel
        progress.horizontalAlignmentMode = .center
        progress.verticalAlignmentMode = .top
        progress.position = CGPoint(x: cx, y: top - 32)
        progress.zPosition = 102
        overlayLayer.addChild(progress)

        // Draft row: saved melds so far (compact strip).
        let draftRowY = top - 78
        addOverlayDraftRow(y: draftRowY, cx: cx, panelWidth: panelW)

        // Status text (from validator on the current staged tray).
        let status = SKLabelNode(text: overlayStatusText())
        status.fontName = theme.bodyFont
        status.fontSize = 12
        status.fontColor = overlayStatusColor()
        status.horizontalAlignmentMode = .center
        status.verticalAlignmentMode = .center
        status.position = CGPoint(x: cx, y: cy + 62)
        status.zPosition = 102
        overlayLayer.addChild(status)

        // Staged cards row.
        let stagedRowY = cy + 22
        addOverlayCardRow(vm.stagedCards, y: stagedRowY, tag: "staged")
        addOverlayRowLabel(text: "Staged  —  tap to remove",
                           y: stagedRowY + CardNode.size.height / 2 + 6, cx: cx)

        // Hand row.
        let handRowInOverlayY = cy - 74
        addOverlayCardRow(vm.unstagedCards, y: handRowInOverlayY, tag: "unstaged")
        addOverlayRowLabel(text: "Your hand  —  tap to stage",
                           y: handRowInOverlayY + CardNode.size.height / 2 + 6, cx: cx)

        // Cancel + Save Meld + Go Down at the bottom.
        let btnY = cy - panelH / 2 + 22
        let stagedValid = (try? vm.stagedValidation?.get()) != nil
        let hasGoneDown = vm.currentPlayer.hasGoneDownThisRound
        addOverlayButton(text: "Cancel", cx: cx - 140, cy: btnY,
                         name: "overlay-cancel", enabled: true)
        addOverlayButton(text: "Save Meld", cx: cx, cy: btnY,
                         name: "overlay-save-meld",
                         enabled: stagedValid && !hasGoneDown)
        addOverlayButton(text: "Go Down", cx: cx + 140, cy: btnY,
                         name: "overlay-confirm",
                         enabled: vm.canConfirmGoDown)
    }

    /// Mini strip near the top of the overlay showing melds the player has
    /// saved into their go-down draft. Each meld is tappable to undo.
    private func addOverlayDraftRow(y: CGFloat, cx: CGFloat, panelWidth: CGFloat) {
        let melds = vm.contractDraft
        addOverlayRowLabel(text: melds.isEmpty
                           ? "Draft: (empty) — build a meld below, then Save"
                           : "Draft  —  tap a meld to undo",
                           y: y + 18, cx: cx)
        guard !melds.isEmpty else { return }
        // Lay each mini-meld left-to-right; scale cards down to fit.
        let scale: CGFloat = 0.45
        let cardW = CardNode.size.width * scale
        let intraMeldGap: CGFloat = 2
        let interMeldGap: CGFloat = 16
        let widths = melds.map { CGFloat($0.count) * cardW + CGFloat($0.count - 1) * intraMeldGap }
        let total = widths.reduce(0, +) + CGFloat(max(0, melds.count - 1)) * interMeldGap
        var x = cx - total / 2
        for (mi, meld) in melds.enumerated() {
            let meldW = widths[mi]
            for (ci, card) in meld.enumerated() {
                let node = CardNode(card: card, faceUp: true, theme: theme)
                node.setScale(scale)
                node.position = CGPoint(x: x + cardW / 2 + CGFloat(ci) * (cardW + intraMeldGap),
                                        y: y)
                node.zPosition = 103
                node.name = "overlay-draft:\(mi)"
                overlayLayer.addChild(node)
            }
            x += meldW + interMeldGap
        }
    }

    private func addOverlayCardRow(_ cards: [Card], y: CGFloat, tag: String) {
        guard !cards.isEmpty else {
            // Empty-state placeholder.
            let placeholder = SKLabelNode(text: "—")
            placeholder.fontName = theme.bodyFont
            placeholder.fontSize = 22
            placeholder.fontColor = theme.contractPillText.withAlphaComponent(0.5)
            placeholder.horizontalAlignmentMode = .center
            placeholder.verticalAlignmentMode = .center
            placeholder.position = CGPoint(x: size.width / 2, y: y)
            placeholder.zPosition = 102
            overlayLayer.addChild(placeholder)
            return
        }
        let cardW = CardNode.size.width
        let spacing: CGFloat = 8
        let total = CGFloat(cards.count) * cardW + CGFloat(cards.count - 1) * spacing
        let startX = size.width / 2 - total / 2 + cardW / 2
        for (i, card) in cards.enumerated() {
            let node = CardNode(card: card, faceUp: true, theme: theme)
            let pos = CGPoint(x: startX + CGFloat(i) * (cardW + spacing), y: y)
            node.position = pos
            node.zPosition = 103
            node.name = "overlay-card-\(tag):\(card.id.uuidString)"
            overlayLayer.addChild(node)
        }
    }

    private func addOverlayRowLabel(text: String, y: CGFloat, cx: CGFloat) {
        let l = SKLabelNode(text: text)
        l.fontName = theme.bodyFont
        l.fontSize = 11
        l.fontColor = theme.pileLabel
        l.horizontalAlignmentMode = .center
        l.verticalAlignmentMode = .bottom
        l.position = CGPoint(x: cx, y: y)
        l.zPosition = 102
        overlayLayer.addChild(l)
    }

    private func addOverlayButton(text: String, cx: CGFloat, cy: CGFloat,
                                  name: String, enabled: Bool) {
        let w: CGFloat = 120
        let h: CGFloat = 30
        let chip = SKShapeNode(rectOf: CGSize(width: w, height: h),
                               cornerRadius: 15)
        chip.fillColor = enabled ? theme.contractPillBg : theme.contractPillBg.withAlphaComponent(0.4)
        chip.strokeColor = enabled ? theme.turnGlow : theme.pileLabel.withAlphaComponent(0.4)
        chip.lineWidth = 1.5
        chip.position = CGPoint(x: cx, y: cy)
        chip.zPosition = 104
        chip.name = enabled ? name : nil
        overlayLayer.addChild(chip)
        let label = SKLabelNode(text: text)
        label.fontName = theme.titleFont
        label.fontSize = 13
        label.fontColor = enabled ? theme.contractPillText : theme.contractPillText.withAlphaComponent(0.5)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = chip.position
        label.zPosition = 105
        label.name = enabled ? name : nil
        overlayLayer.addChild(label)
    }

    private func overlayStatusText() -> String {
        switch vm.stagedValidation {
        case .none:
            return "Tap cards below to stage them"
        case .some(.success(let kind)):
            let label = (kind == .triplet) ? "SET" : "RUN"
            return "✓ Valid \(label) — \(vm.stagedCards.count) cards"
        case .some(.failure(let err)):
            return "✗ \(err.description)"
        }
    }

    private func overlayStatusColor() -> UIColor {
        switch vm.stagedValidation {
        case .some(.success):
            return UIColor(red: 0.55, green: 0.85, blue: 0.55, alpha: 1.0)
        case .some(.failure):
            return UIColor(red: 0.95, green: 0.55, blue: 0.55, alpha: 1.0)
        case .none:
            return theme.pileLabel
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

        // If the meld overlay is open, all touches route to it exclusively.
        if vm.isMeldOverlayOpen {
            handleOverlayTap(at: point)
            return
        }

        // Build-Meld button tap opens the overlay.
        for node in nodes(at: point) {
            if node.name == "build-meld-button" {
                vm.isMeldOverlayOpen = true
                return
            }
        }

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
        if vm.isMeldOverlayOpen { return }
        guard let touch = touches.first, let card = draggingCard else { return }
        card.position = touch.location(in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if vm.isMeldOverlayOpen { return } // handled in touchesBegan
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
        if let id = draggingCardId,
           let card = vm.currentPlayer.hand.first(where: { $0.id == id }) {
            // Drop on discard pile → discard.
            if discardDropZone().contains(point) {
                let ok = vm.dispatch(.discard(playerId: vm.currentPlayer.id, card: card))
                if ok {
                    draggingCard = nil
                    draggingCardId = nil
                    clearDiscardTarget()
                    return
                }
            }
            // Not a drop: was it a tap (barely moved from origin)?
            let dx = point.x - dragOrigin.x
            let dy = point.y - dragOrigin.y
            let tapThreshold: CGFloat = 10
            if abs(dx) < tapThreshold && abs(dy) < tapThreshold {
                if vm.layoffTappedHandCard(card) {
                    draggingCard = nil
                    draggingCardId = nil
                    clearDiscardTarget()
                    return
                }
            }
            // Drag ended within the hand row band → reorder (M2f).
            if isInHandRowBand(point) {
                let targetIdx = reorderTargetIndex(forDropX: point.x, draggedId: id)
                vm.moveHandCard(id, to: targetIdx)
                draggingCard = nil
                draggingCardId = nil
                clearDiscardTarget()
                // Force a rebuild in case the target index equaled the
                // original (no publish → no auto-rebuild from the Combine
                // sink), which would leave the lifted card visually offset.
                rebuildDynamicLayers()
                return
            }
        }

        cancelDrag()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelDrag()
    }

    /// Handles a tap while the meld overlay is open: buttons + card toggles.
    private func handleOverlayTap(at point: CGPoint) {
        for node in nodes(at: point) {
            if node.name == "overlay-cancel" {
                vm.clearStaging()
                vm.clearContractDraft()
                vm.isMeldOverlayOpen = false
                return
            }
            if node.name == "overlay-save-meld" {
                _ = vm.saveStagedAsMeld()
                return
            }
            if node.name == "overlay-confirm" {
                _ = vm.confirmGoDown()
                return
            }
            // Walk up to find the named ancestor for card / draft-meld
            // taps — the touch usually lands on a child sprite (the card
            // background rect or a label) whose parent CardNode carries
            // the "overlay-card-*" / "overlay-draft:*" name.
            var ancestor: SKNode? = node
            while let t = ancestor {
                if let name = t.name {
                    if name.hasPrefix("overlay-draft:") {
                        if let idxStr = name.split(separator: ":").last,
                           let idx = Int(idxStr) {
                            vm.removeDraftMeld(at: idx)
                        }
                        return
                    }
                    if name.hasPrefix("overlay-card-") {
                        if let idStr = name.split(separator: ":").last,
                           let uuid = UUID(uuidString: String(idStr)) {
                            vm.toggleStaged(cardId: uuid)
                        }
                        return
                    }
                }
                ancestor = t.parent
            }
        }
    }

    // MARK: - Hand reorder helpers (M2f)

    /// True if `point` sits in the vertical band occupied by the hand fan —
    /// used to distinguish "drop back to reorder" from "cancel drag".
    private func isInHandRowBand(_ point: CGPoint) -> Bool {
        let halfH = CardNode.size.height * 0.75
        let center = handRowY
        return point.y >= center - halfH && point.y <= center + halfH
    }

    /// Given a drop x-position, compute the target index (in `vm.orderedHand`)
    /// where the dragged card should land. Uses the slot centers captured
    /// during `buildHand`. Filters out the dragged card so we get the index
    /// AFTER removal.
    private func reorderTargetIndex(forDropX x: CGFloat, draggedId: UUID) -> Int {
        let slots = handSlots.filter { $0.id != draggedId }
        guard !slots.isEmpty else { return 0 }
        // Insert before the first slot whose center is to the right of x.
        for (i, slot) in slots.enumerated() where x < slot.x {
            return i
        }
        return slots.count
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
