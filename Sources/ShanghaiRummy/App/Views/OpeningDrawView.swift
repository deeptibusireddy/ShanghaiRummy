import SwiftUI

struct OpeningDrawView: View {
    let stage: GameViewModel.OpeningDrawStage
    let draws: [OpeningDraw]
    let players: [Player]
    let theme: VisualTheme
    let onShowSeatOrder: () -> Void
    let onContinue: () -> Void

    @Namespace private var cardMovement
    @State private var cardsRevealed = false

    private var orderedDraws: [OpeningDraw] {
        switch stage {
        case .drawing:
            return draws
        case .seating:
            let byPlayerId = Dictionary(
                uniqueKeysWithValues: draws.map { ($0.playerId, $0) }
            )
            return players.compactMap { byPlayerId[$0.id] }
        }
    }

    private var playerNames: [UUID: String] {
        Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0.name) })
    }

    var body: some View {
        ZStack {
            Color(theme.background)
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(theme.feltGlow).opacity(0.30),
                    Color(theme.feltFill).opacity(0.92),
                    Color(theme.background),
                ],
                center: .center,
                startRadius: 40,
                endRadius: 720
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                header

                HStack(spacing: 14) {
                    ForEach(Array(orderedDraws.enumerated()), id: \.element.id) {
                        index,
                        draw in
                        OpeningDrawPlayerCard(
                            draw: draw,
                            playerName: playerNames[draw.playerId] ?? "Player",
                            position: stage == .seating ? index + 1 : nil,
                            playerCount: players.count,
                            revealIndex: index,
                            cardsRevealed: cardsRevealed,
                            theme: theme
                        )
                        .matchedGeometryEffect(
                            id: draw.playerId,
                            in: cardMovement
                        )
                        .animation(
                            .spring(
                                response: 0.65,
                                dampingFraction: 0.82
                            ),
                            value: stage
                        )
                    }
                }
                .frame(maxWidth: .infinity)

                footer
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 26)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("opening-seat-draw")
        .onTapGesture {
            if CommandLine.arguments.contains("--ui-testing"),
               stage == .drawing {
                onShowSeatOrder()
            }
        }
        .task {
            do {
                try await Task.sleep(for: .milliseconds(350))
            } catch {
                return
            }
            withAnimation(.easeOut(duration: 0.4)) {
                cardsRevealed = true
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(stage == .drawing ? "DRAW FOR SEATS" : "THE TABLE IS SET")
                .font(.system(
                    size: 34,
                    weight: .black,
                    design: .rounded
                ))
                .tracking(2.4)
                .foregroundStyle(Color(theme.bannerText))
                .accessibilityIdentifier("opening-seat-draw-title")

            Text(headerMessage)
                .font(.system(
                    size: 17,
                    weight: .semibold,
                    design: .rounded
                ))
                .foregroundStyle(Color(theme.seatSub))
                .multilineTextAlignment(.center)
        }
    }

    private var headerMessage: String {
        if stage == .drawing {
            return "Everyone draws one card. Ace is high; tied ranks redraw."
        }
        guard let first = players.first?.name,
              let dealer = players.last?.name else {
            return "Highest to lowest, clockwise around the table."
        }
        return "\(first) plays first. \(dealer) drew lowest and deals."
    }

    @ViewBuilder
    private var footer: some View {
        if stage == .drawing {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(Color(theme.turnGlow))
                Text("Drawing cards…")
                    .font(.system(
                        size: 15,
                        weight: .bold,
                        design: .rounded
                    ))
                    .foregroundStyle(Color(theme.seatSub))
            }
            .frame(height: 46)
        } else {
            VStack(spacing: 12) {
                Text(clockwiseOrder)
                    .font(.system(
                        size: 15,
                        weight: .bold,
                        design: .rounded
                    ))
                    .foregroundStyle(Color(theme.contractPillText))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Button("TAKE YOUR SEATS", action: onContinue)
                    .font(.system(
                        size: 16,
                        weight: .black,
                        design: .rounded
                    ))
                    .foregroundStyle(Color(theme.background))
                    .padding(.horizontal, 24)
                    .frame(height: 46)
                    .background(
                        Capsule()
                            .fill(Color(theme.turnGlow))
                    )
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("opening-seat-draw-continue")
            }
        }
    }

    private var clockwiseOrder: String {
        "CLOCKWISE  •  " + players.map(\.name).joined(separator: "  →  ")
    }
}

private struct OpeningDrawPlayerCard: View {
    let draw: OpeningDraw
    let playerName: String
    let position: Int?
    let playerCount: Int
    let revealIndex: Int
    let cardsRevealed: Bool
    let theme: VisualTheme

    private var cardWidth: CGFloat {
        playerCount >= 6 ? 76 : 86
    }

    private var cardHeight: CGFloat {
        cardWidth * 1.38
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                cardBack
                    .opacity(cardsRevealed ? 0 : 1)
                    .rotation3DEffect(
                        .degrees(cardsRevealed ? -90 : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )

                cardFace
                    .opacity(cardsRevealed ? 1 : 0)
                    .rotation3DEffect(
                        .degrees(cardsRevealed ? 0 : 90),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
            .frame(width: cardWidth, height: cardHeight)
            .animation(
                .easeInOut(duration: 0.45)
                    .delay(revealDelay),
                value: cardsRevealed
            )

            VStack(spacing: 3) {
                Text(playerName)
                    .font(.system(
                        size: 15,
                        weight: .bold,
                        design: .rounded
                    ))
                    .foregroundStyle(Color(theme.seatTitle))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(statusText)
                    .font(.system(
                        size: 11,
                        weight: .black,
                        design: .rounded
                    ))
                    .tracking(0.7)
                    .foregroundStyle(statusColor)
            }
            .frame(width: 112)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(theme.seatBgOther))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            statusColor.opacity(position == nil ? 0.22 : 0.62),
                            lineWidth: position == nil ? 1 : 2
                        )
                )
        )
        .shadow(
            color: Color(theme.cardShadow),
            radius: 9,
            y: 5
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var cardFace: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(theme.cardFace))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(theme.cardStroke), lineWidth: 1)
            )
            .overlay {
                VStack(spacing: 1) {
                    Text(rankText)
                        .font(.system(
                            size: cardWidth * 0.34,
                            weight: .black,
                            design: .rounded
                        ))
                    Text(suitText)
                        .font(.system(size: cardWidth * 0.38))
                }
                .foregroundStyle(suitColor)
            }
    }

    private var cardBack: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(theme.cardBack))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        Color(theme.cardBackAccent),
                        lineWidth: 2
                    )
                    .padding(6)
            )
            .overlay {
                Image(systemName: "sparkles")
                    .font(.system(size: cardWidth * 0.30, weight: .bold))
                    .foregroundStyle(Color(theme.cardBackAccent))
            }
    }

    private var revealDelay: Double {
        Double(revealIndex) * 0.06
    }

    private var statusText: String {
        guard let position else { return "DRAWN CARD" }
        if position == 1 { return "1ST • PLAYS FIRST" }
        if position == playerCount {
            return "\(ordinal(position)) • DEALER"
        }
        return "\(ordinal(position)) • CLOCKWISE"
    }

    private var statusColor: Color {
        position == 1 || position == playerCount
            ? Color(theme.turnGlow)
            : Color(theme.seatSub)
    }

    private var accessibilityLabel: String {
        var label = "\(playerName) drew \(rankText) of \(suitName)"
        if let position {
            label += ", \(ordinal(position)) in clockwise order"
            if position == 1 {
                label += ", plays first"
            } else if position == playerCount {
                label += ", deals first"
            }
        }
        return label
    }

    private var rankText: String {
        switch draw.card.rank {
        case .ace: return "A"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .ten: return "10"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case nil: return "?"
        }
    }

    private var suitText: String {
        switch draw.card.suit {
        case .clubs: return "♣"
        case .diamonds: return "♦"
        case .hearts: return "♥"
        case .spades: return "♠"
        case nil: return ""
        }
    }

    private var suitName: String {
        switch draw.card.suit {
        case .clubs: return "clubs"
        case .diamonds: return "diamonds"
        case .hearts: return "hearts"
        case .spades: return "spades"
        case nil: return "unknown suit"
        }
    }

    private var suitColor: Color {
        switch draw.card.suit {
        case .diamonds, .hearts:
            return Color(theme.redSuit)
        case .clubs, .spades, nil:
            return Color(theme.blackSuit)
        }
    }

    private func ordinal(_ value: Int) -> String {
        switch value {
        case 1: return "1ST"
        case 2: return "2ND"
        case 3: return "3RD"
        default: return "\(value)TH"
        }
    }
}
