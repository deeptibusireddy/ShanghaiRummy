import SwiftUI

/// Full-screen gameplay shell. Core turn interactions live in SpriteKit;
/// SwiftUI owns system-level presentation such as quit, pass-and-play privacy,
/// errors, and end-of-hand summaries.
struct GameContainerView: View {
    @StateObject var vm: GameViewModel
    let theme: VisualTheme
    let onExit: () -> Void

    init(vm: GameViewModel, theme: VisualTheme = .gameNight, onExit: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: vm)
        self.theme = theme
        self.onExit = onExit
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            GameSceneView(vm: vm, theme: theme)
                .background(Color(theme.background))
                .accessibilityIdentifier("game-table")

            Button(action: onExit) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quit game")
            .accessibilityIdentifier("quit-game")
            .padding(.leading, 14)
            .padding(.top, 8)

            VStack {
                Spacer()
                if let err = vm.lastError {
                    Text(err)
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.red.opacity(0.88), in: Capsule())
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .statusBarHidden(true)
        .sheet(isPresented: $vm.isBetweenTurns) {
            PassAndPlayView(nextPlayerName: vm.currentPlayerName) {
                vm.acknowledgeTurnPassed()
            }
            .interactiveDismissDisabled(true)
        }
        .overlay {
            if vm.isHandOver {
                handOverOverlay
            } else if vm.isGameOver {
                gameOverOverlay
            }
        }
    }

    // MARK: - Hand / game over overlays

    private var handOverOverlay: some View {
        VStack(spacing: 14) {
            Text("Hand \(vm.state.currentRound) Over")
                .font(.title2).bold()
            let outName = vm.pendingHandSummary?.first(where: { $0.wentOut })?.name
            if let out = outName {
                Text("\(out) went out")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            scoreTable
            Button("Deal Next Hand") { vm.advanceHand() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: 460)
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
        .padding()
    }

    @ViewBuilder
    private var scoreTable: some View {
        let rows = vm.pendingHandSummary ?? []
        VStack(spacing: 6) {
            HStack {
                Text("Player").frame(maxWidth: .infinity, alignment: .leading)
                Text("Lvl").frame(width: 44, alignment: .trailing)
                Text("Round").frame(width: 60, alignment: .trailing)
                Text("Total").frame(width: 60, alignment: .trailing)
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            Divider()
            ForEach(rows) { row in
                HStack {
                    HStack(spacing: 6) {
                        Text(row.name).bold()
                        if row.wentOut {
                            Text("• out")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                        if row.didLevelUp && !row.wentOut {
                            Text("• down")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 2) {
                        Text("\(row.currentLevel)")
                        if row.didLevelUp {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                    .frame(width: 44, alignment: .trailing)

                    Text("\(row.roundPoints)")
                        .frame(width: 60, alignment: .trailing)
                        .foregroundStyle(row.roundPoints == 0 ? .green : .primary)
                    Text("\(row.totalAfter)")
                        .frame(width: 60, alignment: .trailing)
                        .bold()
                }
                .font(.body)
            }
        }
    }

    private var gameOverOverlay: some View {
        VStack(spacing: 14) {
            Text("🎉 Game Over")
                .font(.title).bold()
            let names = vm.winnerNames
            if names.count > 1 {
                Text("Co-winners: " + names.joined(separator: ", "))
                    .font(.headline)
            } else {
                Text((names.first ?? "Someone") + " wins!")
                    .font(.headline)
            }
            finalTable
            Button("Back to Menu") { onExit() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: 460)
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
        .padding()
    }

    @ViewBuilder
    private var finalTable: some View {
        let rows = vm.finalScoreboard ?? []
        VStack(spacing: 6) {
            HStack {
                Text("Rank").frame(width: 44, alignment: .leading)
                Text("Player").frame(maxWidth: .infinity, alignment: .leading)
                Text("Lvl").frame(width: 44, alignment: .trailing)
                Text("Total").frame(width: 60, alignment: .trailing)
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            Divider()
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                HStack {
                    Text("\(i + 1)")
                        .frame(width: 44, alignment: .leading)
                        .foregroundStyle(row.isWinner ? .yellow : .primary)
                    HStack(spacing: 6) {
                        Text(row.name).bold()
                        if row.isWinner {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(row.currentLevel)")
                        .frame(width: 44, alignment: .trailing)
                    Text("\(row.totalScore)")
                        .frame(width: 60, alignment: .trailing)
                        .bold()
                }
                .font(.body)
            }
        }
    }
}
