import SwiftUI

enum FamilyTableSeatKind: String, CaseIterable, Identifiable {
    case human = "Human"
    case bot = "Bot"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .human: return "person.crop.circle"
        case .bot: return "cpu"
        }
    }
}

struct FamilyTableSeat: Identifiable, Equatable {
    let id: UUID
    var kind: FamilyTableSeatKind

    init(id: UUID = UUID(), kind: FamilyTableSeatKind) {
        self.id = id
        self.kind = kind
    }
}

struct FamilyTableConfiguration: Equatable {
    var seats: [FamilyTableSeat]

    init(seatKinds: [FamilyTableSeatKind] = []) {
        precondition(
            seatKinds.count < RulesConfig.maxPlayers,
            "A table cannot exceed the player limit"
        )
        seats = seatKinds.map { FamilyTableSeat(kind: $0) }
    }

    var totalPlayerCount: Int { seats.count + 1 }
    var invitedHumanCount: Int {
        seats.filter { $0.kind == .human }.count
    }
    var botCount: Int {
        seats.filter { $0.kind == .bot }.count
    }
    var gameCenterPlayerCount: Int { invitedHumanCount + 1 }
    var canAddSeat: Bool { totalPlayerCount < RulesConfig.maxPlayers }

    var actionTitle: String {
        guard !seats.isEmpty else { return "Start Game" }
        if invitedHumanCount == 0 {
            return "Play with \(botCount) \(botCount == 1 ? "Bot" : "Bots")"
        }
        return "Invite \(invitedHumanCount) "
            + (invitedHumanCount == 1 ? "Person" : "People")
    }

    func actionTitle(isGameCenterAuthenticated: Bool) -> String {
        if invitedHumanCount > 0, !isGameCenterAuthenticated {
            return "Sign In & \(actionTitle)"
        }
        return actionTitle
    }

    var canStart: Bool {
        totalPlayerCount >= RulesConfig.minPlayers
            && totalPlayerCount <= RulesConfig.maxPlayers
    }

    @discardableResult
    mutating func addSeat(kind: FamilyTableSeatKind) -> Bool {
        guard canAddSeat else { return false }
        seats.append(FamilyTableSeat(kind: kind))
        return true
    }

    @discardableResult
    mutating func removeSeat(id: UUID) -> Bool {
        guard let index = seats.firstIndex(where: { $0.id == id }) else {
            return false
        }
        seats.remove(at: index)
        return true
    }

    func label(for seatId: UUID) -> String {
        guard let index = seats.firstIndex(where: { $0.id == seatId }) else {
            return "Player"
        }
        let kind = seats[index].kind
        let ordinal = seats[..<index].filter { $0.kind == kind }.count + 1
        return "\(kind.rawValue) \(ordinal)"
    }
}

struct FamilyTableSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var configuration = FamilyTableConfiguration()

    let localPlayerName: String
    let isGameCenterAuthenticated: Bool
    let onStart: (FamilyTableConfiguration) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    localPlayerRow

                    ForEach($configuration.seats) { $seat in
                        HStack(spacing: 12) {
                            Image(systemName: seat.kind.systemImage)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)

                            Text(configuration.label(for: seat.id))
                                .frame(minWidth: 72, alignment: .leading)

                            Picker("Player type", selection: $seat.kind) {
                                ForEach(FamilyTableSeatKind.allCases) { kind in
                                    Text(kind.rawValue).tag(kind)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(maxWidth: 190)

                            Button {
                                configuration.removeSeat(id: seat.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(
                                "Remove \(configuration.label(for: seat.id))"
                            )
                        }
                    }

                    if configuration.canAddSeat {
                        HStack(spacing: 12) {
                            Button {
                                configuration.addSeat(kind: .human)
                            } label: {
                                Label(
                                    "Add Human",
                                    systemImage: "person.badge.plus"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("add-family-human")

                            Button {
                                configuration.addSeat(kind: .bot)
                            } label: {
                                Label("Add Bot", systemImage: "cpu")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("add-family-bot")
                        }
                    }
                } header: {
                    Text("Players (\(configuration.totalPlayerCount))")
                } footer: {
                    Text(footerMessage)
                }

                Section {
                    Button {
                        onStart(configuration)
                    } label: {
                        Text(
                            configuration.actionTitle(
                                isGameCenterAuthenticated:
                                    isGameCenterAuthenticated
                            )
                        )
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!configuration.canStart)
                    .accessibilityIdentifier("start-family-table")
                }
            }
            .navigationTitle("Create Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("family-table-setup")
    }

    private var localPlayerRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("You")
                if !localPlayerName.isEmpty {
                    Text(localPlayerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("This device")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footerMessage: String {
        if configuration.seats.isEmpty {
            return "Add at least one Human or Bot. Tables support 2–6 total "
                + "players."
        }
        if configuration.invitedHumanCount > 0,
           !isGameCenterAuthenticated {
            return "Tap Sign In & Invite to connect this device to Game "
                + "Center. Every player with the app can create a table."
        }
        if configuration.invitedHumanCount == 0 {
            return "Bot-only games start immediately on this device. "
                + "Add up to five bots."
        }
        if configuration.botCount == 0 {
            return "Game Center will open for exactly the selected human seats."
        }
        return "\(configuration.botCount) bot "
            + (configuration.botCount == 1 ? "seat is" : "seats are")
            + " reserved while you invite people through Game Center."
    }
}

#Preview {
    FamilyTableSetupView(
        localPlayerName: "Deepti",
        isGameCenterAuthenticated: true
    ) { _ in }
}
