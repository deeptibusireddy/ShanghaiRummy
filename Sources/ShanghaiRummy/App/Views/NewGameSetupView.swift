import SwiftUI

/// New-game setup: enter player names, pick 2–6 seats, tap Start.
/// Only used by the hot-seat flow. When we add GameKit in M3 this screen won't
/// need to change — a separate flow will fill in the roster from the match.
struct NewGameSetupView: View {
    @State private var players: [String] = ["Player 1", "Player 2"]
    let onStart: (GameViewModel) -> Void

    private let minPlayers = RulesConfig.minPlayers
    private let maxPlayers = RulesConfig.maxPlayers

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(players.indices, id: \.self) { i in
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(.secondary)
                            TextField("Player \(i + 1) name", text: $players[i])
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                        }
                    }
                    .onDelete { indexSet in
                        guard players.count > minPlayers else { return }
                        players.remove(atOffsets: indexSet)
                    }
                } header: {
                    Text("Players (\(players.count))")
                } footer: {
                    Text("Hot-seat mode: pass the device around the table each turn. \(minPlayers)–\(maxPlayers) players.")
                }

                if players.count < maxPlayers {
                    Button {
                        players.append("Player \(players.count + 1)")
                    } label: {
                        Label("Add player", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("New Game")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { start() }
                        .disabled(!canStart)
                }
            }
        }
    }

    private var canStart: Bool {
        players.count >= minPlayers
            && players.count <= maxPlayers
            && players.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func start() {
        let cleaned = players.map { $0.trimmingCharacters(in: .whitespaces) }
        onStart(GameViewModel.newHotSeat(playerNames: cleaned))
    }
}

#Preview {
    NewGameSetupView { _ in }
}
