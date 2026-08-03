import SwiftUI

/// Placeholder game container. Renders a text-only view of the game state so we
/// can drive turns end-to-end before the SpriteKit scene lands in M2b.
///
/// Every action goes through `GameViewModel` so we'll be able to swap the
/// SpriteKit scene in without touching the view model.
struct GameContainerView: View {
    @StateObject var vm: GameViewModel
    let onExit: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header
                Divider()
                tablePlaceholder
                Divider()
                handSection
                if let err = vm.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle("Round \(vm.state.currentRound)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Quit") { onExit() }
                }
            }
            .sheet(isPresented: $vm.isBetweenTurns) {
                PassAndPlayView(nextPlayerName: vm.currentPlayerName) {
                    vm.acknowledgeTurnPassed()
                }
                .interactiveDismissDisabled(true)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 4) {
            Text(vm.currentPlayerName + "'s turn")
                .font(.headline)
            Text("Contract: " + vm.currentContractDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Phase: " + vm.state.phase.rawValue)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var tablePlaceholder: some View {
        HStack(spacing: 24) {
            Button {
                vm.drawFromStock()
            } label: {
                pileCard(label: "Stock", subtitle: "\(vm.state.stock.count) cards")
            }
            .disabled(!vm.canDrawFromStock)

            Button {
                vm.drawFromDiscard()
            } label: {
                pileCard(
                    label: "Discard",
                    subtitle: vm.state.discard.last.map(cardShort) ?? "empty"
                )
            }
            .disabled(!vm.canDrawFromDiscard)
        }
    }

    private var handSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your hand (\(vm.currentPlayer.hand.count))")
                .font(.subheadline).bold()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.currentPlayer.hand, id: \.id) { card in
                        Button {
                            vm.discard(card)
                        } label: {
                            handCard(card)
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.state.phase != .awaitingMeldOrDiscard)
                    }
                }
            }
            Text("Tap a card to discard (temporary placeholder UI).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Card visuals (placeholder)

    private func pileCard(label: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .frame(width: 96, height: 128)
        .background(RoundedRectangle(cornerRadius: 12).fill(.thinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.4)))
    }

    private func handCard(_ card: Card) -> some View {
        VStack {
            Text(cardShort(card))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(cardColor(card))
        }
        .frame(width: 56, height: 84)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.gray))
    }

    private func cardShort(_ card: Card) -> String {
        if card.isPrintedJoker { return "🃏" }
        let suit: String = {
            switch card.suit {
            case .clubs: return "♣"
            case .diamonds: return "♦"
            case .hearts: return "♥"
            case .spades: return "♠"
            case .none: return "?"
            }
        }()
        let rank: String = {
            switch card.rank {
            case .ace: return "A"
            case .jack: return "J"
            case .queen: return "Q"
            case .king: return "K"
            case .some(let r): return "\(r.rawValue)"
            case .none: return "?"
            }
        }()
        let dead = card.isDead2 ? "†" : ""
        return "\(rank)\(suit)\(dead)"
    }

    private func cardColor(_ card: Card) -> Color {
        if card.isPrintedJoker { return .purple }
        switch card.suit {
        case .diamonds, .hearts: return .red
        default: return .black
        }
    }
}
