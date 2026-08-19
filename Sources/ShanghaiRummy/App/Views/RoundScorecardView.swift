import SwiftUI

struct RoundScorecardView: View {
    let handNumber: Int
    let rows: [GameViewModel.HandSummaryRow]
    let canAdvance: Bool
    let nextDealerName: String
    let theme: VisualTheme
    let onAdvance: () -> Void

    var body: some View {
        ScorecardModalShell(
            theme: theme,
            maxWidth: 620,
            accessibilityIdentifier: "hand-over-scorecard"
        ) { compact in
            VStack(spacing: compact ? 12 : 15) {
                header(compact: compact)
                resultNote
                columnHeaders

                VStack(spacing: compact ? 6 : 8) {
                    ForEach(
                        Array(rows.enumerated()),
                        id: \.element.id
                    ) { index, row in
                        scoreRow(
                            row,
                            rank: index + 1,
                            compact: compact
                        )
                    }
                }

                footer
            }
        }
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.14))
                Circle()
                    .stroke(accent.opacity(0.68), lineWidth: 1.5)
                Image(systemName: "flag.checkered")
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
                Text("ROUND SCORECARD")
                    .font(.system(
                        size: compact ? 10 : 11,
                        weight: .black,
                        design: .rounded
                    ))
                    .tracking(2)
                    .foregroundStyle(accent)

                Text("Hand \(handNumber) Complete")
                    .font(.system(
                        compact ? .title2 : .title,
                        design: .rounded,
                        weight: .heavy
                    ))
                    .foregroundStyle(Color(theme.bannerText))
                    .accessibilityIdentifier("hand-over-title")
            }

            Spacer(minLength: 8)

            Text("\(rows.count) PLAYERS")
                .font(.system(
                    size: 10,
                    weight: .black,
                    design: .rounded
                ))
                .tracking(1)
                .foregroundStyle(Color(theme.seatSub))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resultNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "star.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(resultTitle)
                    .font(.system(
                        .subheadline,
                        design: .rounded,
                        weight: .black
                    ))
                    .foregroundStyle(Color(theme.bannerText))

                Text("Round penalties are included in each total.")
                    .font(.system(
                        .caption,
                        design: .rounded,
                        weight: .medium
                    ))
                    .foregroundStyle(Color(theme.seatSub))
            }

            Spacer(minLength: 0)
        }
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
                .frame(width: 92)

            Text("ROUND")
                .frame(width: 70, alignment: .trailing)

            Text("TOTAL")
                .frame(width: 70, alignment: .trailing)
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
        _ row: GameViewModel.HandSummaryRow,
        rank: Int,
        compact: Bool
    ) -> some View {
        HStack(spacing: 12) {
            rankBadge(rank, highlighted: row.wentOut)
            playerLabel(row)
            levelBadge(row)
            scoreMetric(
                row.roundPoints,
                suffix: "PTS",
                highlighted: row.roundPoints == 0,
                compact: compact,
                prefixPlus: row.roundPoints > 0
            )
            scoreMetric(
                row.totalAfter,
                suffix: "TOTAL",
                highlighted: row.wentOut,
                compact: compact,
                prefixPlus: false
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 6 : 8)
        .background(
            rowFill(row),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(rowStroke(row), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(row, rank: rank))
        .accessibilityIdentifier("hand-over-row-\(rank)")
    }

    private func rankBadge(
        _ rank: Int,
        highlighted: Bool
    ) -> some View {
        let fill = highlighted ? accent : accent.opacity(0.12)
        let textColor = highlighted
            ? Color(theme.blackSuit)
            : accent

        return ZStack {
            Circle()
                .fill(fill)
            Text("\(rank)")
                .font(.system(
                    size: 12,
                    weight: .black,
                    design: .rounded
                ))
                .foregroundStyle(textColor)
        }
        .frame(width: 32, height: 32)
    }

    private func playerLabel(
        _ row: GameViewModel.HandSummaryRow
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.name)
                .font(.system(
                    .body,
                    design: .rounded,
                    weight: .bold
                ))
                .foregroundStyle(Color(theme.bannerText))
                .lineLimit(1)

            if row.wentOut {
                statusLabel("WENT OUT", systemImage: "star.fill")
            } else if row.didLevelUp {
                statusLabel(
                    "CONTRACT DOWN",
                    systemImage: "arrow.up.circle.fill"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusLabel(
        _ text: String,
        systemImage: String
    ) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(
                size: 8,
                weight: .black,
                design: .rounded
            ))
            .tracking(0.8)
            .foregroundStyle(accent)
    }

    private func levelBadge(
        _ row: GameViewModel.HandSummaryRow
    ) -> some View {
        VStack(spacing: 0) {
            Text("LV \(row.currentLevel)")
                .font(.system(
                    size: 11,
                    weight: .black,
                    design: .rounded
                ))

            if row.didLevelUp {
                Text("NEXT \(row.currentLevel + 1)")
                    .font(.system(
                        size: 7,
                        weight: .black,
                        design: .rounded
                    ))
                    .tracking(0.6)
                    .foregroundStyle(accent)
            }
        }
        .foregroundStyle(Color(theme.contractPillText))
        .frame(width: 92, height: 34)
        .background(
            Color(theme.scoreChipBg),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(
                    row.didLevelUp
                        ? accent.opacity(0.52)
                        : accent.opacity(0.24),
                    lineWidth: 1
                )
        }
    }

    private func scoreMetric(
        _ score: Int,
        suffix: String,
        highlighted: Bool,
        compact: Bool,
        prefixPlus: Bool
    ) -> some View {
        let scoreColor = highlighted
            ? accent
            : Color(theme.bannerText)
        let scoreText = prefixPlus ? "+\(score)" : "\(score)"

        return VStack(alignment: .trailing, spacing: 0) {
            Text(scoreText)
                .font(.system(
                    compact ? .headline : .title3,
                    design: .rounded,
                    weight: .heavy
                ))
                .foregroundStyle(scoreColor)

            Text(suffix)
                .font(.system(
                    size: 7,
                    weight: .black,
                    design: .rounded
                ))
                .tracking(0.7)
                .foregroundStyle(Color(theme.seatSub))
        }
        .frame(width: 70, alignment: .trailing)
    }

    @ViewBuilder
    private var footer: some View {
        if canAdvance {
            Button(action: onAdvance) {
                Label(
                    "DEAL NEXT HAND",
                    systemImage: "rectangle.stack.fill"
                )
                .font(.system(
                    .headline,
                    design: .rounded,
                    weight: .black
                ))
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(Color(theme.blackSuit))
                .background(
                    accent,
                    in: RoundedRectangle(cornerRadius: 15)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("deal-next-hand")
        } else {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(accent)

                Text(
                    "Waiting for \(nextDealerName) to deal the next hand"
                )
                .font(.system(
                    .subheadline,
                    design: .rounded,
                    weight: .bold
                ))
                .foregroundStyle(Color(theme.bannerText))
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                Color(theme.background).opacity(0.30),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        Color(theme.seatSub).opacity(0.48),
                        lineWidth: 1
                    )
            }
            .accessibilityIdentifier("hand-over-waiting")
        }
    }

    private var resultTitle: String {
        guard let name = rows.first(where: \.wentOut)?.name else {
            return "HAND COMPLETE"
        }
        return "\(name.uppercased()) WENT OUT"
    }

    private func rowFill(
        _ row: GameViewModel.HandSummaryRow
    ) -> Color {
        if row.wentOut {
            return accent.opacity(0.10)
        }
        if row.didLevelUp {
            return accent.opacity(0.05)
        }
        return Color(theme.background).opacity(0.34)
    }

    private func rowStroke(
        _ row: GameViewModel.HandSummaryRow
    ) -> Color {
        if row.wentOut {
            return accent.opacity(0.50)
        }
        if row.didLevelUp {
            return accent.opacity(0.30)
        }
        return Color(theme.seatSub).opacity(0.20)
    }

    private func accessibilityLabel(
        _ row: GameViewModel.HandSummaryRow,
        rank: Int
    ) -> String {
        let status: String
        if row.wentOut {
            status = "went out"
        } else if row.didLevelUp {
            status = "contract down"
        } else {
            status = "did not complete the contract"
        }
        let level = row.didLevelUp
            ? "level \(row.currentLevel), advances to "
                + "\(row.currentLevel + 1)"
            : "level \(row.currentLevel)"
        return "Rank \(rank), \(row.name), \(status), \(level), "
            + "\(row.roundPoints) round points, "
            + "\(row.totalAfter) total points"
    }

    private var accent: Color {
        Color(theme.turnGlow)
    }
}
