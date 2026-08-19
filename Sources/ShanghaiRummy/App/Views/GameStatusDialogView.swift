import SwiftUI

struct GameStatusDialogView: View {
    enum Style {
        case warning
        case success
        case error
    }

    struct Action {
        let title: String
        let accessibilityIdentifier: String
        let handler: () -> Void
    }

    let eyebrow: String
    let title: String
    let message: String
    let symbolName: String
    let style: Style
    let theme: VisualTheme
    let primaryAction: Action
    let secondaryAction: Action?
    let accessibilityIdentifier: String
    let titleAccessibilityIdentifier: String

    var body: some View {
        ScorecardModalShell(
            theme: theme,
            maxWidth: 520,
            accessibilityIdentifier: accessibilityIdentifier,
            accent: accent
        ) { compact in
            VStack(spacing: compact ? 14 : 18) {
                header(compact: compact)
                messagePanel
                actions
            }
        }
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.14))
                Circle()
                    .stroke(accent.opacity(0.68), lineWidth: 1.5)
                Image(systemName: symbolName)
                    .font(.system(
                        size: compact ? 22 : 26,
                        weight: .bold
                    ))
                    .foregroundStyle(accent)
            }
            .frame(
                width: compact ? 50 : 58,
                height: compact ? 50 : 58
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .font(.system(
                        size: compact ? 10 : 11,
                        weight: .black,
                        design: .rounded
                    ))
                    .tracking(2)
                    .foregroundStyle(accent)

                Text(title)
                    .font(.system(
                        compact ? .title2 : .title,
                        design: .rounded,
                        weight: .heavy
                    ))
                    .foregroundStyle(Color(theme.bannerText))
                    .accessibilityIdentifier(titleAccessibilityIdentifier)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var messagePanel: some View {
        Text(message)
            .font(.system(
                .body,
                design: .rounded,
                weight: .medium
            ))
            .foregroundStyle(Color(theme.seatSub))
            .multilineTextAlignment(.leading)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                Color(theme.background).opacity(0.38),
                in: RoundedRectangle(cornerRadius: 15)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(accent.opacity(0.30), lineWidth: 1)
            }
    }

    @ViewBuilder
    private var actions: some View {
        if let secondaryAction {
            HStack(spacing: 12) {
                secondaryButton(secondaryAction)
                primaryButton
            }
        } else {
            primaryButton
        }
    }

    private func secondaryButton(_ action: Action) -> some View {
        Button(action: action.handler) {
            Text(action.title)
                .font(.system(
                    .headline,
                    design: .rounded,
                    weight: .bold
                ))
                .foregroundStyle(Color(theme.bannerText))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    Color(theme.background).opacity(0.30),
                    in: RoundedRectangle(cornerRadius: 15)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(
                            Color(theme.seatSub).opacity(0.56),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }

    private var primaryButton: some View {
        Button(action: primaryAction.handler) {
            Text(primaryAction.title)
                .font(.system(
                    .headline,
                    design: .rounded,
                    weight: .black
                ))
                .foregroundStyle(primaryTextColor)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    accent,
                    in: RoundedRectangle(cornerRadius: 15)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(primaryAction.accessibilityIdentifier)
    }

    private var accent: Color {
        switch style {
        case .success:
            return Color(theme.turnGlow)
        case .warning, .error:
            return Color(theme.redSuit)
        }
    }

    private var primaryTextColor: Color {
        switch style {
        case .success:
            return Color(theme.blackSuit)
        case .warning, .error:
            return .white
        }
    }
}
