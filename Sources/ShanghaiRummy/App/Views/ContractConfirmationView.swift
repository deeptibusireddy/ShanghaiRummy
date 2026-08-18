import SwiftUI

struct ContractConfirmationView: View {
    let prompt: GameViewModel.ContractReadyPrompt
    let level: Int
    let contractDescription: String
    let savedMeldCount: Int
    let remainingCardCount: Int
    let theme: VisualTheme
    let onPutDown: () -> Void
    let onReview: () -> Void
    let onDiscardAnyway: () -> Void

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
                        accent.opacity(isDiscardWarning ? 0.24 : 0.18),
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
        .sensoryFeedback(
            isDiscardWarning ? .warning : .success,
            trigger: hasAppeared
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("contract-ready-overlay")
        .accessibilityAddTraits(.isModal)
    }

    private func panel(compact: Bool) -> some View {
        VStack(spacing: compact ? 13 : 17) {
            confirmationMark(compact: compact)

            VStack(spacing: 5) {
                Text(eyebrow)
                    .font(.system(
                        size: compact ? 11 : 12,
                        weight: .black,
                        design: .rounded
                    ))
                    .tracking(2.2)
                    .foregroundStyle(accent)

                Text(title)
                    .font(.system(
                        compact ? .title2 : .title,
                        design: .rounded,
                        weight: .heavy
                    ))
                    .foregroundStyle(Color(theme.bannerText))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("contract-ready-title")
            }

            contractStatus

            Text(message)
                .font(.system(
                    compact ? .subheadline : .body,
                    design: .rounded,
                    weight: .medium
                ))
                .foregroundStyle(Color(theme.seatSub))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let discardCard {
                discardWarning(card: discardCard)
            }

            actions
        }
        .padding(.horizontal, compact ? 24 : 30)
        .padding(.vertical, compact ? 20 : 26)
        .frame(maxWidth: 540)
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

    private func confirmationMark(compact: Bool) -> some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.14))
            Circle()
                .stroke(accent.opacity(0.68), lineWidth: 1.5)
            Image(systemName: isDiscardWarning
                ? "exclamationmark.triangle.fill"
                : "checkmark.seal.fill")
                .font(.system(
                    size: compact ? 25 : 30,
                    weight: .bold
                ))
                .foregroundStyle(accent)
        }
        .frame(
            width: compact ? 54 : 64,
            height: compact ? 54 : 64
        )
        .shadow(color: accent.opacity(0.24), radius: 12)
    }

    private var contractStatus: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.3.group.fill")
                    .foregroundStyle(Color(theme.turnGlow))

                Text("LEVEL \(level)")
                    .font(.system(
                        .caption,
                        design: .rounded,
                        weight: .black
                    ))
                    .tracking(1)
                    .foregroundStyle(Color(theme.contractPillText))

                Circle()
                    .fill(Color(theme.seatSub))
                    .frame(width: 4, height: 4)

                Text(contractDescription.uppercased())
                    .font(.system(
                        .caption,
                        design: .rounded,
                        weight: .bold
                    ))
                    .foregroundStyle(Color(theme.bannerText))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Text(summary)
                .font(.system(
                    size: 11,
                    weight: .black,
                    design: .rounded
                ))
                .tracking(0.9)
                .foregroundStyle(Color(theme.seatSub))
                .accessibilityIdentifier("contract-ready-summary")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(
            Color(theme.background).opacity(0.44),
            in: RoundedRectangle(cornerRadius: 15)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    Color(theme.turnGlow).opacity(0.32),
                    lineWidth: 1
                )
        }
        .accessibilityIdentifier("contract-ready-contract")
    }

    private func discardWarning(card: Card) -> some View {
        HStack(spacing: 13) {
            ContractDiscardCardView(card: card, theme: theme)

            VStack(alignment: .leading, spacing: 4) {
                Text("SELECTED TO DISCARD")
                    .font(.system(
                        size: 10,
                        weight: .black,
                        design: .rounded
                    ))
                    .tracking(1.2)
                    .foregroundStyle(accent)

                Text(CardNode.shortName(card))
                    .font(.system(
                        .headline,
                        design: .rounded,
                        weight: .bold
                    ))
                    .foregroundStyle(Color(theme.bannerText))

                Text("Discarding clears this saved contract arrangement.")
                    .font(.system(
                        .caption,
                        design: .rounded,
                        weight: .medium
                    ))
                    .foregroundStyle(Color(theme.seatSub))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            accent.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(accent.opacity(0.45), lineWidth: 1)
        }
        .accessibilityIdentifier("contract-ready-discard-card")
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: onPutDown) {
                Label(
                    "PUT DOWN CONTRACT",
                    systemImage: "checkmark.seal.fill"
                )
                .font(.system(
                    .headline,
                    design: .rounded,
                    weight: .black
                ))
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(Color(theme.blackSuit))
                .background(
                    Color(theme.turnGlow),
                    in: RoundedRectangle(cornerRadius: 15)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("contract-ready-put-down")

            if isDiscardWarning {
                Button(action: onDiscardAnyway) {
                    Label(
                        "DISCARD ANYWAY",
                        systemImage: "arrow.right.circle"
                    )
                    .font(.system(
                        .subheadline,
                        design: .rounded,
                        weight: .bold
                    ))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(accent)
                    .background(
                        accent.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(accent.opacity(0.72), lineWidth: 1.2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("contract-ready-discard-anyway")
            } else {
                Button(action: onReview) {
                    Label(
                        "REVIEW MELDS",
                        systemImage: "rectangle.3.group"
                    )
                    .font(.system(
                        .subheadline,
                        design: .rounded,
                        weight: .bold
                    ))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(Color(theme.bannerText))
                    .background(
                        Color(theme.background).opacity(0.30),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                Color(theme.seatSub).opacity(0.56),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("contract-ready-review")
            }
        }
    }

    private var isDiscardWarning: Bool {
        if case .confirmDiscard(_) = prompt {
            return true
        }
        return false
    }

    private var discardCard: Card? {
        if case .confirmDiscard(let card) = prompt {
            return card
        }
        return nil
    }

    private var accent: Color {
        isDiscardWarning
            ? Color(theme.redSuit)
            : Color(theme.turnGlow)
    }

    private var eyebrow: String {
        isDiscardWarning ? "ONE LAST CHECK" : "CONTRACT COMPLETE"
    }

    private var title: String {
        isDiscardWarning
            ? "Put Down Before Discarding?"
            : "Your Contract Is Ready"
    }

    private var message: String {
        if let discardCard {
            return "Your contract is still ready. Put it down before "
                + "discarding \(CardNode.shortName(discardCard)), or continue "
                + "and clear the saved arrangement."
        }
        return "Your saved melds complete this level. Put them on the table "
            + "now, or review the arrangement before committing."
    }

    private var summary: String {
        let meldWord = savedMeldCount == 1 ? "MELD" : "MELDS"
        let cardWord = remainingCardCount == 1 ? "CARD" : "CARDS"
        return "\(savedMeldCount) \(meldWord) SAVED  •  "
            + "\(remainingCardCount) \(cardWord) REMAIN"
    }
}

private struct ContractDiscardCardView: View {
    let card: Card
    let theme: VisualTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(rankText)
                .font(.system(
                    size: 18,
                    weight: .black,
                    design: .rounded
                ))
            Image(systemName: suitSymbol)
                .font(.system(size: 18, weight: .black))
        }
        .foregroundStyle(cardColor)
        .padding(8)
        .frame(width: 52, height: 66, alignment: .topLeading)
        .background(
            Color(theme.cardFace),
            in: RoundedRectangle(cornerRadius: 9)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color(theme.cardStroke), lineWidth: 1.2)
        }
        .shadow(color: .black.opacity(0.28), radius: 5, y: 3)
        .accessibilityLabel(CardNode.shortName(card))
    }

    private var rankText: String {
        guard !card.isPrintedJoker, let rank = card.rank else {
            return "J"
        }
        switch rank {
        case .ace: return "A"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        default: return "\(rank.rawValue)"
        }
    }

    private var suitSymbol: String {
        guard !card.isPrintedJoker, let suit = card.suit else {
            return "star.fill"
        }
        switch suit {
        case .clubs: return "suit.club.fill"
        case .diamonds: return "suit.diamond.fill"
        case .hearts: return "suit.heart.fill"
        case .spades: return "suit.spade.fill"
        }
    }

    private var cardColor: Color {
        if card.isPrintedJoker {
            return Color(theme.jokerAccent)
        }
        switch card.suit {
        case .some(.diamonds), .some(.hearts):
            return Color(theme.redSuit)
        case .some(.clubs), .some(.spades), .none:
            return Color(theme.blackSuit)
        }
    }
}
