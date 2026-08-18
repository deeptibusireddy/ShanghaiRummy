import SwiftUI

enum TableAssemblyStage: Equatable {
    case choosingGuests
    case gathering
    case ready
}

enum TableAssemblySeatStatus: Equatable {
    case ready
    case choose
    case joining
}

struct TableAssemblySeatPresentation: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let badge: String
    let kind: FamilyTableSeatKind
    let status: TableAssemblySeatStatus
    let accessibilityIdentifier: String
}

struct TableAssemblyPresentation: Equatable {
    let configuration: FamilyTableConfiguration
    let connectedGuestNames: [String]
    let isMatchActive: Bool
    let statusMessage: String

    var connectedGuestCount: Int {
        min(connectedGuestNames.count, configuration.invitedHumanCount)
    }

    var remainingGuestCount: Int {
        max(configuration.invitedHumanCount - connectedGuestCount, 0)
    }

    var stage: TableAssemblyStage {
        if connectedGuestCount == configuration.invitedHumanCount {
            return .ready
        }
        return isMatchActive ? .gathering : .choosingGuests
    }

    var headline: String {
        switch stage {
        case .choosingGuests:
            return "CHOOSE YOUR\nGUESTS"
        case .gathering:
            return "THE TABLE\nIS GATHERING"
        case .ready:
            return "EVERYONE\nIS HERE"
        }
    }

    var explanation: String {
        switch stage {
        case .choosingGuests:
            return "Your house players and settings are reserved. "
                + "Choose the people who will join them."
        case .gathering:
            return "Your complete guest list stays visible while Game Center "
                + "brings everyone to the table."
        case .ready:
            return "The guest list is complete. The opening draw will decide "
                + "where everyone sits and who deals first."
        }
    }

    var progressTitle: String {
        switch stage {
        case .choosingGuests:
            return "\(configuration.invitedHumanCount) "
                + guestNoun(configuration.invitedHumanCount)
                + " to choose"
        case .gathering:
            return "\(connectedGuestCount) of "
                + "\(configuration.invitedHumanCount) "
                + (configuration.invitedHumanCount == 1
                    ? "guest joined"
                    : "guests joined")
        case .ready:
            return "Everyone is ready"
        }
    }

    var progressDetail: String {
        if stage == .ready {
            return "Drawing cards for seating order..."
        }
        if !statusMessage.isEmpty {
            return statusMessage
        }
        switch stage {
        case .choosingGuests:
            return "Game Center opens as a guest chooser. "
                + "Your bots remain reserved here."
        case .gathering:
            return remainingGuestCount == 1
                ? "Waiting for one guest to join."
                : "Waiting for \(remainingGuestCount) guests to join."
        case .ready:
            return "Drawing cards for seating order..."
        }
    }

    var chooseGuestsTitle: String {
        "Choose \(configuration.invitedHumanCount) "
            + guestNoun(configuration.invitedHumanCount)
            + " in Game Center"
    }

    var configuredSeats: [TableAssemblySeatPresentation] {
        var humanIndex = 0
        return configuration.seats.map { seat in
            let configuredTitle = configuration.label(for: seat.id)
            switch seat.kind {
            case .bot:
                let difficulty = seat.botDifficulty ?? .hard
                return TableAssemblySeatPresentation(
                    id: seat.id,
                    title: configuredTitle,
                    subtitle: "House player - \(difficulty.displayName)",
                    badge: "READY",
                    kind: .bot,
                    status: .ready,
                    accessibilityIdentifier:
                        "table-assembly-\(identifier(for: configuredTitle))"
                )
            case .human:
                defer { humanIndex += 1 }
                let guestNumber = humanIndex + 1
                if connectedGuestNames.indices.contains(humanIndex) {
                    return TableAssemblySeatPresentation(
                        id: seat.id,
                        title: connectedGuestNames[humanIndex],
                        subtitle: "Game Center guest",
                        badge: "READY",
                        kind: .human,
                        status: .ready,
                        accessibilityIdentifier:
                            "table-assembly-human-\(guestNumber)"
                    )
                }
                return TableAssemblySeatPresentation(
                    id: seat.id,
                    title: "Guest \(guestNumber)",
                    subtitle: isMatchActive
                        ? "Joining through Game Center"
                        : "Choose in Game Center",
                    badge: isMatchActive ? "JOINING" : "INVITE",
                    kind: .human,
                    status: isMatchActive ? .joining : .choose,
                    accessibilityIdentifier:
                        "table-assembly-human-\(guestNumber)"
                )
            }
        }
    }

    private func guestNoun(_ count: Int) -> String {
        count == 1 ? "Guest" : "Guests"
    }

    private func identifier(for title: String) -> String {
        title.lowercased().replacingOccurrences(of: " ", with: "-")
    }
}

struct TableAssemblyLaunchConfiguration {
    enum PreviewStage {
        case choosingGuests
        case gathering
        case ready
    }

    let configuration: FamilyTableConfiguration
    let connectedGuestNames: [String]
    let isMatchActive: Bool
    let statusMessage: String

    static func current(
        arguments: [String] = CommandLine.arguments
    ) -> TableAssemblyLaunchConfiguration? {
        let stage: PreviewStage
        if arguments.contains("--demo-table-assembly-choose") {
            stage = .choosingGuests
        } else if arguments.contains("--demo-table-assembly-gathering") {
            stage = .gathering
        } else if arguments.contains("--demo-table-assembly-ready") {
            stage = .ready
        } else {
            return nil
        }

        var configuration = FamilyTableConfiguration(
            seatKinds: [.human, .bot, .bot]
        )
        let botSeats = configuration.seats.filter { $0.kind == .bot }
        if let firstBot = botSeats.first {
            configuration.setBotDifficulty(.medium, for: firstBot.id)
        }

        switch stage {
        case .choosingGuests:
            return TableAssemblyLaunchConfiguration(
                configuration: configuration,
                connectedGuestNames: [],
                isMatchActive: false,
                statusMessage: ""
            )
        case .gathering:
            return TableAssemblyLaunchConfiguration(
                configuration: configuration,
                connectedGuestNames: [],
                isMatchActive: true,
                statusMessage: "Waiting for your guest to join..."
            )
        case .ready:
            return TableAssemblyLaunchConfiguration(
                configuration: configuration,
                connectedGuestNames: ["Morgan"],
                isMatchActive: true,
                statusMessage: "Starting the shared table..."
            )
        }
    }
}

struct TableAssemblyView: View {
    let configuration: FamilyTableConfiguration
    let localPlayerName: String
    let connectedGuestNames: [String]
    let isMatchActive: Bool
    let statusMessage: String
    let errorMessage: String?
    let onChooseGuests: () -> Void
    let onEditTable: () -> Void
    let onLeaveTable: () -> Void

    @State private var isConfirmingLeave = false
    private let palette = EntryFinalistPalette.midnightDeco

    private var presentation: TableAssemblyPresentation {
        TableAssemblyPresentation(
            configuration: configuration,
            connectedGuestNames: connectedGuestNames,
            isMatchActive: isMatchActive,
            statusMessage: statusMessage
        )
    }

    var body: some View {
        ZStack {
            MidnightDecoBackdrop(palette: palette)

            VStack(spacing: 0) {
                EntryNavigationBar(
                    title: "Gathering the Table",
                    seatCount: configuration.totalPlayerCount,
                    palette: palette,
                    onBack: navigateBack
                )

                HStack(spacing: 28) {
                    dossier
                    roster
                }
                .padding(.horizontal, 64)
                .padding(.top, 34)
                .padding(.bottom, 48)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("table-assembly")
        .alert("Leave this table?", isPresented: $isConfirmingLeave) {
            Button("Keep Waiting", role: .cancel) {}
            Button("Leave Table", role: .destructive, action: onLeaveTable)
        } message: {
            Text(
                "The connected match will close, but you can create another "
                    + "table from the home screen."
            )
        }
    }

    private var dossier: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR TABLE IS RESERVED")
                .font(.system(size: 14, weight: .black))
                .tracking(3.4)
                .foregroundStyle(palette.gold)

            Text(presentation.headline)
                .font(.system(
                    size: 39,
                    weight: .black,
                    design: .rounded
                ))
                .tracking(-1.4)
                .foregroundStyle(palette.text)
                .lineSpacing(-7)
                .padding(.top, 16)
                .accessibilityIdentifier("table-assembly-title")

            Text(presentation.explanation)
                .font(.body.weight(.medium))
                .foregroundStyle(palette.muted)
                .lineSpacing(4)
                .padding(.top, 20)

            HStack(spacing: 8) {
                assemblyMetric(
                    value: configuration.humanCount,
                    label: "Humans"
                )
                assemblyMetric(
                    value: configuration.botCount,
                    label: "Bots"
                )
                assemblyMetric(
                    value: configuration.totalPlayerCount,
                    label: "Total"
                )
            }
            .padding(.top, 24)

            Spacer(minLength: 18)

            VStack(spacing: 12) {
                assemblyStep(
                    number: 1,
                    title: "Guest list",
                    detail: "Table reserved",
                    state: .complete
                )
                assemblyStep(
                    number: 2,
                    title: "Invitations",
                    detail: presentation.stage == .ready
                        ? "Guests ready"
                        : "Current step",
                    state: presentation.stage == .ready
                        ? .complete
                        : .current
                )
                assemblyStep(
                    number: 3,
                    title: "Seating draw",
                    detail: presentation.stage == .ready
                        ? "Starting now"
                        : "Up next",
                    state: presentation.stage == .ready
                        ? .current
                        : .upcoming
                )
            }
        }
        .padding(30)
        .frame(width: 310)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            ChamferedRectangle(corner: 22)
                .fill(palette.panelStrong.opacity(0.96))
                .overlay(
                    ChamferedRectangle(corner: 22)
                        .stroke(palette.gold, lineWidth: 2)
                )
        )
    }

    private var roster: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tonight's players")
                        .font(.title3.weight(.bold))
                    Text("Guest list only. Seating order is drawn next.")
                        .font(.subheadline)
                        .foregroundStyle(palette.muted)
                }
                Spacer()
                Text("\(configuration.totalPlayerCount) places reserved")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.muted)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ],
                spacing: 12
            ) {
                hostSeat

                ForEach(presentation.configuredSeats) { seat in
                    TableAssemblyPlayerCard(
                        presentation: seat,
                        palette: palette
                    )
                }

                ForEach(
                    0..<configuration.openSeatCount,
                    id: \.self
                ) { offset in
                    TableAssemblyEmptySeat(
                        seatNumber:
                            configuration.totalPlayerCount + offset + 1,
                        palette: palette
                    )
                }
            }
            .frame(height: 240, alignment: .top)

            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(presentation.progressTitle)
                        .font(.subheadline.weight(.bold))
                    Text(errorMessage ?? presentation.progressDetail)
                        .font(.caption)
                        .foregroundStyle(
                            errorMessage == nil
                                ? palette.muted
                                : palette.accent
                        )
                        .lineLimit(2)
                        .accessibilityIdentifier("table-assembly-status")
                }

                Spacer(minLength: 12)

                Button(
                    isMatchActive ? "Leave Table" : "Edit Table",
                    action: navigateBack
                )
                .buttonStyle(EntrySecondaryButtonStyle(
                    foreground: palette.text,
                    stroke: palette.muted
                ))
                .accessibilityIdentifier(
                    isMatchActive
                        ? "table-assembly-leave"
                        : "table-assembly-edit"
                )

                if presentation.stage == .choosingGuests {
                    Button(action: onChooseGuests) {
                        Label(
                            presentation.chooseGuestsTitle,
                            systemImage: "person.2.badge.plus"
                        )
                    }
                    .buttonStyle(EntryPrimaryButtonStyle(
                        fill: palette.accent,
                        foreground: palette.background
                    ))
                    .accessibilityIdentifier(
                        "table-assembly-choose-guests"
                    )
                } else {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(palette.gold)
                        Text(
                            presentation.stage == .ready
                                ? "DRAWING FOR SEATS"
                                : "GATHERING PLAYERS"
                        )
                        .font(.caption.weight(.black))
                        .tracking(1)
                    }
                    .foregroundStyle(palette.gold)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                    .background(
                        Capsule()
                            .fill(palette.gold.opacity(0.10))
                            .overlay(
                                Capsule().stroke(
                                    palette.gold.opacity(0.45),
                                    lineWidth: 1
                                )
                            )
                    )
                }
            }
        }
        .foregroundStyle(palette.text)
        .padding(24)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(palette.panel.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(palette.muted.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private var hostSeat: some View {
        TableAssemblyPlayerCard(
            presentation: TableAssemblySeatPresentation(
                id: UUID(),
                title: "You",
                subtitle: localPlayerName.isEmpty
                    ? "Host - this iPad"
                    : "\(localPlayerName) - this iPad",
                badge: "HOST - READY",
                kind: .human,
                status: .ready,
                accessibilityIdentifier: "table-assembly-host"
            ),
            palette: palette,
            isHost: true
        )
    }

    private func navigateBack() {
        if isMatchActive {
            isConfirmingLeave = true
        } else {
            onEditTable()
        }
    }

    private func assemblyMetric(
        value: Int,
        label: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title3.weight(.black))
                .foregroundStyle(palette.gold)
            Text(label.uppercased())
                .font(.caption2.weight(.black))
                .tracking(0.8)
                .foregroundStyle(palette.muted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(palette.panel.opacity(0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(palette.muted.opacity(0.20), lineWidth: 1)
                )
        )
    }

    private enum AssemblyStepState: Equatable {
        case complete
        case current
        case upcoming
    }

    private func assemblyStep(
        number: Int,
        title: String,
        detail: String,
        state: AssemblyStepState
    ) -> some View {
        let color = state == .upcoming ? palette.muted : palette.gold
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(state == .current ? 0.20 : 0.08))
                Circle()
                    .stroke(color.opacity(0.72), lineWidth: 1)
                if state == .complete {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.black))
                } else {
                    Text("\(number)")
                        .font(.caption2.weight(.black))
                }
            }
            .foregroundStyle(color)
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(
                        state == .upcoming ? palette.muted : palette.text
                    )
                Text(detail.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .tracking(0.9)
                    .foregroundStyle(color)
            }

            Spacer()
        }
    }
}

struct GameCenterTableContextBanner: View {
    let configuration: FamilyTableConfiguration
    let notice: String?

    private let palette = EntryFinalistPalette.midnightDeco

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("YOUR SHANGHAI RUMMY TABLE")
                    .font(.caption.weight(.black))
                    .tracking(1.8)
                    .foregroundStyle(palette.gold)
                Spacer()
                Text("\(configuration.totalPlayerCount) PLAYERS")
                    .font(.caption2.weight(.black))
                    .tracking(1)
                    .foregroundStyle(palette.muted)
            }

            HStack(spacing: 8) {
                contextChip("You", systemImage: "person.fill")

                ForEach(
                    Array(configuration.seats.filter {
                        $0.kind == .bot
                    }.enumerated()),
                    id: \.element.id
                ) { index, seat in
                    contextChip(
                        "Bot \(index + 1) "
                            + (seat.botDifficulty ?? .hard).displayName,
                        systemImage: "cpu"
                    )
                }

                contextChip(
                    "\(configuration.invitedHumanCount) "
                        + (configuration.invitedHumanCount == 1
                            ? "Guest"
                            : "Guests"),
                    systemImage: "person.badge.plus"
                )
            }

            Text(notice ?? defaultNotice)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: 760)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(palette.panelStrong.opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(palette.gold, lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("game-center-table-context")
    }

    private var defaultNotice: String {
        "Choose exactly \(configuration.invitedHumanCount) "
            + (configuration.invitedHumanCount == 1 ? "guest" : "guests")
            + ". Your bots and their strength settings remain reserved."
    }

    private func contextChip(
        _ title: String,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.bold))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(palette.panel)
                    .overlay(
                        Capsule().stroke(
                            palette.muted.opacity(0.28),
                            lineWidth: 1
                        )
                    )
            )
    }
}

private struct TableAssemblyPlayerCard: View {
    let presentation: TableAssemblySeatPresentation
    let palette: EntryFinalistPalette
    var isHost = false

    private var accent: Color {
        if isHost { return palette.gold }
        if presentation.kind == .bot { return palette.gold }
        switch presentation.status {
        case .ready: return palette.success
        case .choose: return palette.accent
        case .joining: return palette.gold
        }
    }

    private var avatarText: String {
        if isHost { return "Y" }
        if presentation.kind == .bot { return "B" }
        return String(presentation.title.prefix(1)).uppercased()
    }

    var body: some View {
        HStack(spacing: 11) {
            Text(avatarText)
                .font(.caption.weight(.black))
                .foregroundStyle(palette.background)
                .frame(width: 36, height: 36)
                .background(Circle().fill(accent))

            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                Text(presentation.subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 5)

            if presentation.status == .joining {
                ProgressView()
                    .controlSize(.small)
                    .tint(accent)
            }

            Text(presentation.badge)
                .font(.system(size: 9, weight: .black))
                .tracking(0.8)
                .foregroundStyle(accent)
                .lineLimit(1)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(palette.panelStrong.opacity(isHost ? 1 : 0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(
                            isHost ? palette.gold : accent.opacity(0.38),
                            lineWidth: isHost ? 1.5 : 1
                        )
                )
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accent)
                        .frame(width: 3)
                        .padding(.vertical, 12)
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(presentation.accessibilityIdentifier)
    }
}

private struct TableAssemblyEmptySeat: View {
    let seatNumber: Int
    let palette: EntryFinalistPalette

    var body: some View {
        VStack(spacing: 4) {
            Text("OPEN PLACE \(seatNumber)")
                .font(.caption2.weight(.black))
                .tracking(1.2)
            Text("Not part of tonight's table")
                .font(.caption2)
                .opacity(0.76)
        }
        .foregroundStyle(palette.muted)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(palette.panelStrong.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(
                            palette.muted.opacity(0.22),
                            style: StrokeStyle(
                                lineWidth: 1,
                                dash: [5, 5]
                            )
                        )
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(
            "table-assembly-open-seat-\(seatNumber)"
        )
    }
}
