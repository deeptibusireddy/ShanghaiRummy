import SwiftUI

struct GameOverCelebrationView: View {
    let rows: [GameViewModel.FinalScoreRow]
    let winnerNames: [String]
    let theme: VisualTheme
    let onExit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 1_050

            ZStack {
                celebrationBackground

                CelebrationConfettiView(
                    colors: [
                        Color(theme.turnGlow),
                        Color(theme.redSuit),
                        Color(theme.feltGlow),
                        Color(theme.contractPillText),
                        Color(theme.seatTitle),
                    ],
                    reduceMotion: reduceMotion
                )

                VStack(spacing: compact ? 12 : 18) {
                    championHeader(compact: compact)

                    HStack(alignment: .center, spacing: compact ? 14 : 22) {
                        podium(compact: compact)
                            .frame(maxWidth: .infinity)

                        fullStandings(compact: compact)
                            .frame(width: compact ? 300 : 360)
                    }
                    .frame(maxHeight: .infinity)

                    Button("Back to Menu", action: onExit)
                        .font(.system(
                            .headline,
                            design: .rounded,
                            weight: .bold
                        ))
                        .foregroundStyle(Color(theme.blackSuit))
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(
                            Color(theme.turnGlow),
                            in: Capsule()
                        )
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("game-over-back-to-menu")
                }
                .padding(.horizontal, compact ? 24 : 42)
                .padding(.vertical, compact ? 18 : 28)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.76)) {
                    hasAppeared = true
                }
            }
        }
        .sensoryFeedback(.success, trigger: hasAppeared)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("game-over-celebration")
        .accessibilityAddTraits(.isModal)
    }

    private var celebrationBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(theme.background),
                    Color(theme.feltFill),
                    Color(theme.contractPillBg),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(theme.turnGlow).opacity(0.34),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 260
                    )
                )
                .frame(width: 520, height: 520)
                .offset(x: -300, y: -180)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(theme.feltGlow).opacity(0.28),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .offset(x: 360, y: 230)
        }
    }

    private func championHeader(compact: Bool) -> some View {
        VStack(spacing: compact ? 4 : 7) {
            Text("SHANGHAI RUMMY NIGHTS")
                .font(.system(
                    compact ? .caption : .subheadline,
                    design: .rounded,
                    weight: .heavy
                ))
                .tracking(3)
                .foregroundStyle(Color(theme.contractPillText))

            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(Color(theme.turnGlow))
                    .symbolEffect(
                        .bounce,
                        options: .repeat(2),
                        value: reduceMotion ? false : hasAppeared
                    )

                Text(
                    winnerNames.count > 1
                        ? "Tonight's Co-Champions"
                        : "Tonight's Champion"
                )
                .font(.system(
                    compact ? .title2 : .title,
                    design: .rounded,
                    weight: .bold
                ))
                .foregroundStyle(Color(theme.seatTitle))

                Image(systemName: "crown.fill")
                    .foregroundStyle(Color(theme.turnGlow))
                    .symbolEffect(
                        .bounce,
                        options: .repeat(2),
                        value: reduceMotion ? false : hasAppeared
                    )
            }

            Text(championNames)
                .font(.system(
                    .largeTitle,
                    design: .rounded,
                    weight: .heavy
                ))
                .foregroundStyle(Color(theme.turnGlow))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("Contract 10 complete • A night to remember")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(theme.seatSub))
        }
        .scaleEffect(hasAppeared ? 1 : 0.9)
        .opacity(hasAppeared ? 1 : 0)
    }

    private var championNames: String {
        guard !winnerNames.isEmpty else { return "Champion" }
        if winnerNames.count == 1 {
            return winnerNames[0]
        }
        return winnerNames.joined(separator: " & ")
    }

    private func podium(compact: Bool) -> some View {
        let topRows = Array(rows.prefix(3))

        return VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            Label("The Podium", systemImage: "trophy.fill")
                .font(.system(
                    compact ? .headline : .title3,
                    design: .rounded,
                    weight: .bold
                ))
                .foregroundStyle(Color(theme.seatTitle))

            HStack(alignment: .bottom, spacing: compact ? 9 : 14) {
                ForEach(Array(topRows.enumerated()), id: \.element.id) {
                    index,
                    row in
                    podiumCard(
                        row,
                        displayIndex: index,
                        compact: compact
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func podiumCard(
        _ row: GameViewModel.FinalScoreRow,
        displayIndex: Int,
        compact: Bool
    ) -> some View {
        let isChampion = row.isWinner
        let width: CGFloat = compact
            ? (isChampion ? 148 : 128)
            : (isChampion ? 182 : 154)
        let height: CGFloat = compact
            ? (isChampion ? 214 : 186)
            : (isChampion ? 252 : 218)

        return VStack(spacing: compact ? 8 : 11) {
            Text(ordinal(row.placement))
                .font(.system(
                    compact ? .subheadline : .headline,
                    design: .rounded,
                    weight: .heavy
                ))
                .foregroundStyle(placementColor(row.placement))
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    placementColor(row.placement).opacity(0.14),
                    in: Capsule()
                )

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                placementColor(row.placement),
                                placementColor(row.placement).opacity(0.55),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(String(row.name.prefix(1)).uppercased())
                    .font(.system(
                        compact ? .title2 : .title,
                        design: .rounded,
                        weight: .heavy
                    ))
                    .foregroundStyle(Color(theme.blackSuit))

                if isChampion {
                    Image(systemName: "crown.fill")
                        .font(.system(size: compact ? 18 : 22))
                        .foregroundStyle(Color(theme.turnGlow))
                        .offset(y: compact ? -36 : -43)
                }
            }
            .frame(
                width: compact ? 58 : 70,
                height: compact ? 58 : 70
            )

            Text(row.name)
                .font(.system(
                    compact ? .headline : .title3,
                    design: .rounded,
                    weight: .bold
                ))
                .foregroundStyle(Color(theme.seatTitle))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(
                row.isWinner
                    ? "10/10 complete"
                    : "\(row.contractsCompleted)/10 contracts"
            )
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(Color(theme.contractPillText))

            Text("\(row.totalScore) pts")
                .font(.system(
                    compact ? .subheadline : .headline,
                    design: .rounded,
                    weight: .bold
                ))
                .foregroundStyle(Color(theme.seatSub))
        }
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 12 : 16)
        .frame(width: width, height: height)
        .background(
            Color(theme.scoreChipBg).opacity(isChampion ? 0.98 : 0.88),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    isChampion
                        ? Color(theme.turnGlow)
                        : placementColor(row.placement).opacity(0.65),
                    lineWidth: isChampion ? 3 : 1.5
                )
        }
        .shadow(
            color: isChampion
                ? Color(theme.turnGlow).opacity(0.34)
                : .black.opacity(0.24),
            radius: isChampion ? 20 : 10,
            y: 7
        )
        .scaleEffect(hasAppeared ? 1 : 0.82)
        .opacity(hasAppeared ? 1 : 0)
        .animation(
            reduceMotion
                ? nil
                : .spring(response: 0.65, dampingFraction: 0.72)
                    .delay(Double(displayIndex) * 0.11),
            value: hasAppeared
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(ordinal(row.placement)) place, \(row.name), "
                + "\(row.contractsCompleted) of 10 contracts complete, "
                + "\(row.totalScore) points"
        )
        .accessibilityIdentifier("podium-place-\(displayIndex + 1)")
    }

    private func fullStandings(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 10) {
            Text("Final Standings")
                .font(.system(
                    compact ? .headline : .title3,
                    design: .rounded,
                    weight: .bold
                ))
                .foregroundStyle(Color(theme.seatTitle))

            Text("Progress decides placement • lower score breaks ties")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color(theme.seatSub))

            HStack {
                Text("Place")
                    .frame(width: compact ? 42 : 48, alignment: .leading)
                Text("Player")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Done")
                    .frame(width: compact ? 42 : 48, alignment: .trailing)
                Text("Score")
                    .frame(width: compact ? 48 : 56, alignment: .trailing)
            }
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(Color(theme.seatSub))

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: compact ? 6 : 8) {
                    Text(ordinal(row.placement))
                        .font(.system(
                            .subheadline,
                            design: .rounded,
                            weight: .heavy
                        ))
                        .foregroundStyle(placementColor(row.placement))
                        .frame(
                            width: compact ? 42 : 48,
                            alignment: .leading
                        )

                    HStack(spacing: 5) {
                        Text(row.name)
                            .font(.system(
                                .subheadline,
                                design: .rounded,
                                weight: row.isWinner ? .bold : .semibold
                            ))
                            .lineLimit(1)
                        if row.isWinner {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(Color(theme.turnGlow))
                        }
                    }
                    .foregroundStyle(Color(theme.seatTitle))
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(row.contractsCompleted)/10")
                        .frame(
                            width: compact ? 42 : 48,
                            alignment: .trailing
                        )
                    Text("\(row.totalScore)")
                        .fontWeight(.bold)
                        .frame(
                            width: compact ? 48 : 56,
                            alignment: .trailing
                        )
                }
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color(theme.seatSub))
                .padding(.horizontal, 9)
                .padding(.vertical, compact ? 7 : 9)
                .background(
                    row.isWinner
                        ? Color(theme.turnGlow).opacity(0.12)
                        : Color(theme.scoreChipBg).opacity(0.52),
                    in: RoundedRectangle(cornerRadius: 11)
                )
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("final-standing-\(index + 1)")
            }
        }
        .padding(compact ? 14 : 18)
        .background(
            Color(theme.contractPillBg).opacity(0.9),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color(theme.feltStroke), lineWidth: 1.5)
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(x: hasAppeared ? 0 : 28)
        .animation(
            reduceMotion
                ? nil
                : .easeOut(duration: 0.5).delay(0.18),
            value: hasAppeared
        )
    }

    private func placementColor(_ placement: Int) -> Color {
        switch placement {
        case 1:
            return Color(theme.turnGlow)
        case 2:
            return Color(theme.seatTitle)
        case 3:
            return Color(theme.redSuit).opacity(0.88)
        default:
            return Color(theme.seatSub)
        }
    }

    private func ordinal(_ value: Int) -> String {
        let tens = value % 100
        if 11...13 ~= tens {
            return "\(value)th"
        }
        switch value % 10 {
        case 1: return "\(value)st"
        case 2: return "\(value)nd"
        case 3: return "\(value)rd"
        default: return "\(value)th"
        }
    }
}

private struct CelebrationConfettiView: View {
    let colors: [Color]
    let reduceMotion: Bool

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 30.0,
                paused: reduceMotion
            )
        ) { timeline in
            Canvas { context, size in
                guard !colors.isEmpty else { return }
                let time = timeline.date.timeIntervalSinceReferenceDate
                let particleCount = reduceMotion ? 28 : 64

                for index in 0..<particleCount {
                    let lane = Double((index * 73) % 997) / 997.0
                    let phase = Double((index * 37) % 100) / 100.0
                    let speed = 0.055 + Double(index % 7) * 0.006
                    let progress = (time * speed + phase)
                        .truncatingRemainder(dividingBy: 1)
                    let sway = sin(time * 0.9 + Double(index)) * 18
                    let width = CGFloat(5 + (index % 4) * 2)
                    let height = CGFloat(10 + (index % 3) * 4)
                    let rect = CGRect(
                        x: CGFloat(lane) * size.width + CGFloat(sway),
                        y: CGFloat(progress) * (size.height + 80) - 40,
                        width: width,
                        height: height
                    )
                    context.fill(
                        Path(
                            roundedRect: rect,
                            cornerRadius: min(width, height) / 3
                        ),
                        with: .color(
                            colors[index % colors.count].opacity(0.86)
                        )
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
