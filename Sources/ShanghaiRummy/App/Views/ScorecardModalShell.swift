import SwiftUI

struct ScorecardModalShell<Content: View>: View {
    let theme: VisualTheme
    let maxWidth: CGFloat
    let accessibilityIdentifier: String
    private let content: (Bool) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    init(
        theme: VisualTheme,
        maxWidth: CGFloat,
        accessibilityIdentifier: String,
        @ViewBuilder content: @escaping (Bool) -> Content
    ) {
        self.theme = theme
        self.maxWidth = maxWidth
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content
    }

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
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityAddTraits(.isModal)
    }

    private func panel(compact: Bool) -> some View {
        content(compact)
            .padding(.horizontal, compact ? 22 : 28)
            .padding(.vertical, compact ? 20 : 26)
            .frame(maxWidth: compact ? maxWidth - 40 : maxWidth)
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

    private var accent: Color {
        Color(theme.turnGlow)
    }
}
