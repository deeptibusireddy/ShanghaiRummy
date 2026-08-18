import SwiftUI

struct LiveScorecardView: View {
    let rows: [GameViewModel.LiveScoreRow]
    let theme: VisualTheme
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 760

            ZStack {
                Color.black.opacity(0.62)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())

                RadialGradient(
                    colors: [
                        accent.opacity(0.18),
                        .clear,
                    ],
                    center: .center,
                    startRadius: 30,
                    endRadius: compact ? 330 : 440
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                panel(compact: compact)
                    .padding(.horizontal, 28)
                    .scaleEffect(hasAppeared ? 1 : 0.94)
                    .opacity(hasAppeared ? 1 : 0)
            }
        }
        .onAppear {
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(
                    .spring(response: 0.48, dampingFraction: 0.82)
                ) {
                    hasAppeared = true
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("live-scorecard")
        .accessibilityAddTraits(.isModal)
    }

    private func panel(compact: Bool) -> some View {
        VStack(spacing: compact ? 12 : 15) {
            header(compact: compact)
            standingsNote
            columnHeaders

            VStack(spacing: compact ? 6 : 8) {
                ForEach(
                    Array(rows.enumerated()),
                    id: \.element.id
                ) { index, row in
                    scoreRow(row, rank: index + 1, compact: compact)
                }
            }
        }
        .padding(.horizontal, compact ? 22 : 28)
        .padding(.vertical, compact ? 20 : 26)
        .frame(maxWidth: compact ? 460 : 500)
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(theme.contractPillBg),
                            Color(theme.scoreChipBg),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(accent.opacity(0.92), lineWidth: 2)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(accent)
                .frame(width: 92, height: 4)
                .offset(y: 10)
        }
        .shadow(color: .black.opacity(0.48), radius: 28, y: 14)
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.14))
                Circle()
                    .stroke(accent.opacity(0.68), lineWidth: 1.5)
                Image(systemName: "list.number")
                    .font(.system(
                        size: compact ? 20 : 23,
                        weight: .black
                    ))
                    .foregroundStyle(accent)
            }
            .frame(
                width: compact ? 44 : 50,
                height: compact ? 44 : 50
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE SHEET")
                    .font(.system(
                        size: compact ? 10 : 11,
                        weight: .black,
                        design: .rounded
                    ))
                    .tracking(2)
                    .foregroundStyle(accent)

                Text("Current Score")
                    .font(.system(
                        compact ? .title2 : .title,
                        design: .rounded,
                        weight: .heavy
                    ))
                    .foregroundStyle(Color(theme.bannerText))
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(
                        size: 15,
                        weight: .black,
                        design: .rounded
                    ))
                    .foregroundStyle(Color(theme.bannerText))
                    .frame(width: 42, height: 42)
                    .background(
                        Color(theme.background).opacity(0.36),
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .stroke(
                                Color(theme.seatSub).opacity(0.52),
                                lineWidth: 1
                            )
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close scorecard")
            .accessibilityIdentifier("dismiss-live-scorecard")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var standingsNote: some View {
        Label(
            "LOWEST CUMULATIVE SCORE LEADS",
            systemImage: "arrow.down.circle.fill"
        )
        .font(.system(
            size: 10,
            weight: .black,
            design: .rounded
        ))
        .tracking(0.8)
        .foregroundStyle(Color(theme.contractPillText))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Color(theme.background).opacity(0.38),
            in: RoundedRectangle(cornerRadius: 13)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        }
    }

    private var columnHeaders: some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(width: 32, height: 1)

            Text("PLAYER")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("LEVEL")
                .frame(width: 70)

            Text("TOTAL")
                .frame(width: 64, alignment: .trailing)
        }
        .font(.system(
            size: 9,
            weight: .black,
            design: .rounded
        ))
        .tracking(1.1)
        .foregroundStyle(Color(theme.seatSub))
        .padding(.horizontal, 12)
    }

    private func scoreRow(
        _ row: GameViewModel.LiveScoreRow,
        rank: Int,
        compact: Bool
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        rank == 1
                            ? accent
                            : accent.opacity(0.12)
                    )
                Text("\(rank)")
                    .font(.system(
                        size: 12,
                        weight: .black,
                        design: .rounded
                    ))
                    .foregroundStyle(
                        rank == 1
                            ? Color(theme.blackSuit)
                            : accent
                    )
            }
            .frame(width: 32, height: 32)

            HStack(spacing: 6) {
                Text(row.name)
                    .font(.system(
                        .body,
                        design: .rounded,
                        weight: .bold
                    ))
                    .foregroundStyle(Color(theme.bannerText))
                    .lineLimit(1)

                if rank == 1 {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("LV \(row.currentLevel)")
                .font(.system(
                    size: 11,
                    weight: .black,
                    design: .rounded
                ))
                .foregroundStyle(Color(theme.contractPillText))
                .frame(width: 70, minHeight: 30)
                .background(
                    Color(theme.scoreChipBg),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(accent.opacity(0.34), lineWidth: 1)
                }

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(row.totalScore)")
                    .font(.system(
                        compact ? .headline : .title3,
                        design: .rounded,
                        weight: .heavy
                    ))
                    .foregroundStyle(
                        rank == 1
                            ? accent
                            : Color(theme.bannerText)
                    )

                Text("PTS")
                    .font(.system(
                        size: 8,
                        weight: .black,
                        design: .rounded
                    ))
                    .tracking(0.8)
                    .foregroundStyle(Color(theme.seatSub))
            }
            .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 7 : 9)
        .background(
            rank == 1
                ? accent.opacity(0.10)
                : Color(theme.background).opacity(0.34),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    rank == 1
                        ? accent.opacity(0.50)
                        : Color(theme.seatSub).opacity(0.20),
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Rank \(rank), \(row.name), level \(row.currentLevel), "
                + "\(row.totalScore) points"
        )
        .accessibilityIdentifier("live-scorecard-row-\(rank)")
    }

    private var accent: Color {
        Color(theme.turnGlow)
    }
}
