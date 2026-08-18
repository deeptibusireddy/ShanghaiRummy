import Foundation
import SwiftUI

enum EntryFinalistDesign: String {
    case midnightDeco = "midnight-deco"
    case bundAfterDark = "bund-after-dark"
}

enum EntryFinalistScreen: String {
    case home
    case invite
}

struct EntryFinalistLaunchConfiguration {
    let design: EntryFinalistDesign
    let screen: EntryFinalistScreen

    static func current(
        arguments: [String] = CommandLine.arguments
    ) -> EntryFinalistLaunchConfiguration? {
        guard arguments.contains("--demo-entry-finalist"),
              let designValue = value(
                after: "--entry-finalist-design",
                in: arguments
              ),
              let design = EntryFinalistDesign(rawValue: designValue),
              let screenValue = value(
                after: "--entry-finalist-screen",
                in: arguments
              ),
              let screen = EntryFinalistScreen(rawValue: screenValue) else {
            return nil
        }
        return EntryFinalistLaunchConfiguration(
            design: design,
            screen: screen
        )
    }

    private static func value(
        after flag: String,
        in arguments: [String]
    ) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return arguments[valueIndex]
    }
}

struct EntryFinalistPreviewHost: View {
    let design: EntryFinalistDesign
    @State private var screen: EntryFinalistScreen
    @State private var configuration = FamilyTableConfiguration(
        seatKinds: [.human, .human, .bot]
    )

    init(design: EntryFinalistDesign, screen: EntryFinalistScreen) {
        self.design = design
        _screen = State(initialValue: screen)
    }

    var body: some View {
        ZStack {
            switch (design, screen) {
            case (.midnightDeco, .home):
                MidnightDecoHomeView {
                    screen = .invite
                }
            case (.midnightDeco, .invite):
                MidnightDecoTableView(
                    configuration: $configuration,
                    localPlayerName: "Deepti",
                    isGameCenterAuthenticated: true,
                    onBack: { screen = .home },
                    onStart: { _ in }
                )
            case (.bundAfterDark, .home):
                BundAfterDarkHomeView(
                    localPlayerName: "Deepti",
                    isGameCenterAuthenticated: true,
                    errorMessage: nil,
                    onCreateTable: { screen = .invite },
                    onAuthenticate: {},
                    onSoundSettings: {}
                )
            case (.bundAfterDark, .invite):
                BundAfterDarkTableView(
                    configuration: $configuration,
                    localPlayerName: "Deepti",
                    isGameCenterAuthenticated: true,
                    onBack: { screen = .home },
                    onStart: {}
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            "entry-finalist-\(design.rawValue)-\(screen.rawValue)"
        )
    }
}

private struct EntryFinalistPalette {
    let background: Color
    let backgroundSecondary: Color
    let panel: Color
    let panelStrong: Color
    let text: Color
    let muted: Color
    let accent: Color
    let gold: Color
    let success: Color

    static let midnightDeco = EntryFinalistPalette(
        background: Color(red: 0.035, green: 0.040, blue: 0.105),
        backgroundSecondary: Color(red: 0.075, green: 0.070, blue: 0.155),
        panel: Color(red: 0.095, green: 0.085, blue: 0.175),
        panelStrong: Color(red: 0.135, green: 0.110, blue: 0.205),
        text: Color(red: 1.000, green: 0.965, blue: 0.890),
        muted: Color(red: 0.730, green: 0.710, blue: 0.800),
        accent: Color(red: 0.930, green: 0.245, blue: 0.405),
        gold: Color(red: 0.985, green: 0.690, blue: 0.285),
        success: Color(red: 0.310, green: 0.780, blue: 0.590)
    )

    static let bundAfterDark = EntryFinalistPalette(
        background: Color(red: 0.025, green: 0.050, blue: 0.115),
        backgroundSecondary: Color(red: 0.090, green: 0.075, blue: 0.170),
        panel: Color(red: 0.070, green: 0.085, blue: 0.155),
        panelStrong: Color(red: 0.120, green: 0.120, blue: 0.210),
        text: Color(red: 1.000, green: 0.965, blue: 0.890),
        muted: Color(red: 0.710, green: 0.730, blue: 0.825),
        accent: Color(red: 0.940, green: 0.260, blue: 0.420),
        gold: Color(red: 0.995, green: 0.715, blue: 0.300),
        success: Color(red: 0.320, green: 0.790, blue: 0.610)
    )
}

private struct MidnightDecoHomeView: View {
    private let palette = EntryFinalistPalette.midnightDeco
    let onCreateTable: () -> Void

    var body: some View {
        ZStack {
            MidnightDecoBackdrop(palette: palette)

            VStack(spacing: 0) {
                EntryTopStatus(
                    palette: palette,
                    trailingText: "Deepti",
                    trailingSubtitle: "Game Center",
                    isConnected: true
                )

                HStack(spacing: 56) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("THE TABLE IS OPEN")
                            .font(.system(size: 15, weight: .black))
                            .tracking(4.2)
                            .foregroundStyle(palette.gold)

                        Text("SHANGHAI\nRUMMY")
                            .font(.system(
                                size: 76,
                                weight: .black,
                                design: .rounded
                            ))
                            .tracking(-3.2)
                            .foregroundStyle(palette.text)
                            .lineSpacing(-14)
                            .padding(.top, 18)

                        Text("N I G H T S")
                            .font(.system(size: 34, weight: .black))
                            .tracking(7)
                            .foregroundStyle(palette.accent)
                            .padding(.top, 8)

                        Text("Cards, company, and one more hand.")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(palette.muted)
                            .padding(.top, 20)

                        HStack(spacing: 14) {
                            Button("Create a Table", action: onCreateTable)
                                .buttonStyle(EntryPrimaryButtonStyle(
                                    fill: palette.accent,
                                    foreground: palette.background
                                ))
                                .accessibilityIdentifier("create-table")

                            Button("How to Play") {}
                                .buttonStyle(EntrySecondaryButtonStyle(
                                    foreground: palette.text,
                                    stroke: palette.muted
                                ))
                        }
                        .padding(.top, 28)

                        Label(
                            "Invite people through Game Center or fill the table with bots.",
                            systemImage: "person.3.fill"
                        )
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(palette.muted)
                        .padding(.top, 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    DecoCardShowpiece(palette: palette)
                        .frame(width: 390, height: 410)
                }
                .padding(.horizontal, 92)
                .padding(.top, 56)
                .padding(.bottom, 66)
            }
        }
        .ignoresSafeArea()
    }
}

struct MidnightDecoTableView: View {
    @Binding var configuration: FamilyTableConfiguration
    let localPlayerName: String
    let isGameCenterAuthenticated: Bool
    let onBack: () -> Void
    let onStart: (FamilyTableConfiguration) -> Void
    private let palette = EntryFinalistPalette.midnightDeco

    init(
        configuration: Binding<FamilyTableConfiguration>,
        localPlayerName: String,
        isGameCenterAuthenticated: Bool,
        onBack: @escaping () -> Void,
        onStart: @escaping (FamilyTableConfiguration) -> Void
    ) {
        _configuration = configuration
        self.localPlayerName = localPlayerName
        self.isGameCenterAuthenticated = isGameCenterAuthenticated
        self.onBack = onBack
        self.onStart = onStart
    }

    var body: some View {
        ZStack {
            MidnightDecoBackdrop(palette: palette)

            VStack(spacing: 0) {
                EntryNavigationBar(
                    title: "Create Table",
                    seatCount: configuration.totalPlayerCount,
                    palette: palette,
                    onBack: onBack
                )

                HStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("TONIGHT'S DOSSIER")
                            .font(.system(size: 14, weight: .black))
                            .tracking(3.8)
                            .foregroundStyle(palette.gold)

                        Text("YOUR TABLE\nIS TAKING\nSHAPE")
                            .font(.system(
                                size: 41,
                                weight: .black,
                                design: .rounded
                            ))
                            .tracking(-1.5)
                            .foregroundStyle(palette.text)
                            .lineSpacing(-7)
                            .padding(.top, 16)

                        Text(
                            "Every place is reserved from the start, so the "
                                + "room stays calm while the guest list changes."
                        )
                        .font(.body.weight(.medium))
                        .foregroundStyle(palette.muted)
                        .lineSpacing(4)
                        .padding(.top, 20)

                        HStack(spacing: 8) {
                            EntryCountMetric(
                                value: configuration.humanCount,
                                label: "Humans",
                                palette: palette
                            )
                            EntryCountMetric(
                                value: configuration.botCount,
                                label: "Bots",
                                palette: palette
                            )
                            EntryCountMetric(
                                value: configuration.totalPlayerCount,
                                label: "Total",
                                palette: palette
                            )
                        }
                        .padding(.top, 24)

                        EntryDossierDetail(
                            label: "Evening forecast",
                            value: "About "
                                + "\(configuration.estimatedDurationMinutes) "
                                + "minutes",
                            detail: "10 levels",
                            palette: palette
                        )
                        .padding(.top, 18)

                        EntryDossierDetail(
                            label: "Table policy",
                            value: "Up to 3 buys each hand",
                            detail: "Classic rules",
                            palette: palette
                        )

                        Spacer(minLength: 12)

                        EntryOccupancyDots(
                            occupiedCount: configuration.totalPlayerCount,
                            palette: palette
                        )
                    }
                    .padding(30)
                    .frame(width: 310)
                    .background(
                        ChamferedRectangle(corner: 22)
                            .fill(palette.panelStrong.opacity(0.96))
                            .overlay(
                                ChamferedRectangle(corner: 22)
                                    .stroke(palette.gold, lineWidth: 2)
                            )
                    )

                    EntryRosterPanel(
                        configuration: $configuration,
                        palette: palette,
                        localPlayerName: localPlayerName,
                        isGameCenterAuthenticated: isGameCenterAuthenticated,
                        actionTitle: configuration.actionTitle(
                            isGameCenterAuthenticated:
                                isGameCenterAuthenticated
                        ),
                        actionSystemImage: isGameCenterAuthenticated
                            ? "person.2.badge.plus"
                            : "person.crop.circle.badge.checkmark",
                        onStart: {
                            onStart(configuration)
                        }
                    )
                }
                .padding(.horizontal, 64)
                .padding(.top, 34)
                .padding(.bottom, 48)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("family-table-setup")
    }
}

struct BundAfterDarkHomeView: View {
    private let palette = EntryFinalistPalette.bundAfterDark
    @AppStorage(TurnSoundPreferences.enabledKey)
    private var turnSoundsEnabled = true
    let localPlayerName: String
    let isGameCenterAuthenticated: Bool
    let errorMessage: String?
    let onCreateTable: () -> Void
    let onAuthenticate: () -> Void
    let onSoundSettings: () -> Void

    init(
        localPlayerName: String,
        isGameCenterAuthenticated: Bool,
        errorMessage: String?,
        onCreateTable: @escaping () -> Void,
        onAuthenticate: @escaping () -> Void,
        onSoundSettings: @escaping () -> Void
    ) {
        self.localPlayerName = localPlayerName
        self.isGameCenterAuthenticated = isGameCenterAuthenticated
        self.errorMessage = errorMessage
        self.onCreateTable = onCreateTable
        self.onAuthenticate = onAuthenticate
        self.onSoundSettings = onSoundSettings
    }

    var body: some View {
        ZStack {
            BundAfterDarkBackdrop(palette: palette)

            VStack(spacing: 0) {
                EntryTopStatus(
                    palette: palette,
                    trailingText: statusTitle,
                    trailingSubtitle: statusSubtitle,
                    isConnected: isGameCenterAuthenticated
                )

                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("THE SUPPER CLUB IS OPEN")
                            .font(.system(size: 15, weight: .black))
                            .tracking(4.2)
                            .foregroundStyle(palette.gold)

                        Text("Shanghai\nRummy")
                            .font(.system(
                                size: 74,
                                weight: .black,
                                design: .rounded
                            ))
                            .tracking(-3.4)
                            .foregroundStyle(palette.text)
                            .lineSpacing(-15)
                            .padding(.top, 18)

                        Text("Nights")
                            .font(.system(
                                size: 54,
                                weight: .bold,
                                design: .rounded
                            ))
                            .foregroundStyle(palette.accent)
                            .padding(.top, 4)

                        Rectangle()
                            .fill(palette.gold)
                            .frame(width: 124, height: 4)
                            .padding(.vertical, 22)

                        Text("Cards, company, and one more hand.")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(palette.muted)

                        HStack(spacing: 14) {
                            Button("Create a Table", action: onCreateTable)
                                .buttonStyle(EntryPrimaryButtonStyle(
                                    fill: palette.accent,
                                    foreground: palette.background
                                ))
                                .accessibilityIdentifier("create-table")

                            if isGameCenterAuthenticated {
                                Label(
                                    "Game Center Ready",
                                    systemImage: "checkmark.circle.fill"
                                )
                                .font(.headline.weight(.bold))
                                .foregroundStyle(palette.success)
                                .padding(.horizontal, 18)
                            } else {
                                Button(
                                    "Sign In to Game Center",
                                    action: onAuthenticate
                                )
                                .buttonStyle(EntrySecondaryButtonStyle(
                                    foreground: palette.text,
                                    stroke: palette.muted
                                ))
                                .accessibilityIdentifier(
                                    "sign-in-game-center"
                                )
                            }

                            Button(action: onSoundSettings) {
                                Label(
                                    "Sounds",
                                    systemImage: turnSoundsEnabled
                                        ? "speaker.wave.2.fill"
                                        : "speaker.slash.fill"
                                )
                            }
                            .buttonStyle(EntrySecondaryButtonStyle(
                                foreground: palette.text,
                                stroke: palette.muted
                            ))
                            .accessibilityLabel(
                                turnSoundsEnabled
                                    ? "Turn sound settings, sounds on"
                                    : "Turn sound settings, sounds off"
                            )
                            .accessibilityIdentifier(
                                "home-turn-sound-settings"
                            )
                        }
                        .padding(.top, 28)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(palette.accent)
                                .frame(maxWidth: 520, alignment: .leading)
                                .padding(.top, 16)
                        }
                    }
                    .frame(maxWidth: 650, alignment: .leading)

                    Spacer()
                }
                .padding(.horizontal, 92)
                .padding(.top, 72)

                Spacer()
            }
        }
        .ignoresSafeArea()
    }

    private var statusTitle: String {
        if isGameCenterAuthenticated, !localPlayerName.isEmpty {
            return localPlayerName
        }
        return "Game Center"
    }

    private var statusSubtitle: String {
        isGameCenterAuthenticated ? "Connected" : "Not signed in"
    }
}

private struct BundAfterDarkTableView: View {
    @Binding var configuration: FamilyTableConfiguration
    let localPlayerName: String
    let isGameCenterAuthenticated: Bool
    let onBack: () -> Void
    let onStart: () -> Void
    private let palette = EntryFinalistPalette.bundAfterDark

    var body: some View {
        ZStack {
            BundAfterDarkBackdrop(palette: palette)

            VStack(spacing: 0) {
                EntryNavigationBar(
                    title: "Create Table",
                    seatCount: configuration.totalPlayerCount,
                    palette: palette,
                    onBack: onBack
                )

                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("TONIGHT'S TABLE")
                            .font(.system(size: 14, weight: .black))
                            .tracking(3.6)
                            .foregroundStyle(palette.gold)

                        Text("Room on\nthe Bund")
                            .font(.system(
                                size: 47,
                                weight: .black,
                                design: .rounded
                            ))
                            .tracking(-1.7)
                            .foregroundStyle(palette.text)
                            .lineSpacing(-7)
                            .padding(.top, 16)

                        Text(
                            "Set the guest list, then open Game Center "
                                + "for exactly the selected people."
                        )
                        .font(.body.weight(.medium))
                        .foregroundStyle(palette.muted)
                        .lineSpacing(4)
                        .padding(.top, 20)

                        Spacer()

                        Text("TABLE 1930")
                            .font(.caption.weight(.black))
                            .tracking(2.2)
                            .foregroundStyle(palette.gold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .overlay(
                                Capsule()
                                    .stroke(palette.gold, lineWidth: 1.5)
                            )
                    }
                    .padding(30)
                    .frame(width: 315)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(palette.panelStrong.opacity(0.94))
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(palette.accent)
                                    .frame(width: 6)
                            }
                    )

                    EntryRosterPanel(
                        configuration: $configuration,
                        palette: palette,
                        localPlayerName: localPlayerName,
                        isGameCenterAuthenticated: isGameCenterAuthenticated,
                        actionTitle: configuration.actionTitle(
                            isGameCenterAuthenticated:
                                isGameCenterAuthenticated
                        ),
                        actionSystemImage: "gamecontroller.fill",
                        onStart: onStart
                    )
                }
                .padding(.horizontal, 64)
                .padding(.top, 34)
                .padding(.bottom, 48)
            }
        }
        .ignoresSafeArea()
    }
}

private struct EntryTopStatus: View {
    let palette: EntryFinalistPalette
    let trailingText: String
    let trailingSubtitle: String
    let isConnected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SHANGHAI RUMMY NIGHTS")
                    .font(.caption.weight(.black))
                    .tracking(2.4)
                Text("A social card game for 2-6 players")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(palette.muted)
            }

            Spacer()

            HStack(spacing: 9) {
                Circle()
                    .fill(isConnected ? palette.success : palette.gold)
                    .frame(width: 9, height: 9)
                    .shadow(
                        color: (
                            isConnected ? palette.success : palette.gold
                        ).opacity(0.55),
                        radius: 6
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(trailingText)
                        .font(.caption.weight(.bold))
                    Text(trailingSubtitle)
                        .font(.caption2)
                        .foregroundStyle(palette.muted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(palette.panel.opacity(0.90))
                    .overlay(
                        Capsule()
                            .stroke(palette.muted.opacity(0.32), lineWidth: 1)
                    )
            )
        }
        .foregroundStyle(palette.text)
        .padding(.horizontal, 54)
        .padding(.top, 28)
    }
}

private struct EntryNavigationBar: View {
    let title: String
    let seatCount: Int
    let palette: EntryFinalistPalette
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .background(
                Circle()
                    .fill(palette.panel.opacity(0.92))
                    .overlay(
                        Circle().stroke(
                            palette.muted.opacity(0.35),
                            lineWidth: 1
                        )
                    )
            )
            .accessibilityLabel("Back")

            Spacer()

            VStack(spacing: 2) {
                Text(title)
                    .font(.title3.weight(.bold))
                Text("Private table")
                    .font(.caption)
                    .foregroundStyle(palette.muted)
            }

            Spacer()

            Text("\(seatCount) of 6 seats")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.muted)
                .frame(width: 112, alignment: .trailing)
        }
        .foregroundStyle(palette.text)
        .padding(.horizontal, 54)
        .padding(.top, 28)
    }
}

private struct EntryRosterPanel: View {
    @Binding var configuration: FamilyTableConfiguration
    let palette: EntryFinalistPalette
    let localPlayerName: String
    let isGameCenterAuthenticated: Bool
    let actionTitle: String
    let actionSystemImage: String
    let onStart: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tonight's players")
                        .font(.title3.weight(.bold))
                    Text("People, house players, or a little of both.")
                        .font(.subheadline)
                        .foregroundStyle(palette.muted)
                }
                Spacer()
                Text("\(configuration.totalPlayerCount) of 6 seated")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.muted)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                EntryHostSeatCard(
                    localPlayerName: localPlayerName,
                    palette: palette
                )

                ForEach(configuration.seats) { seat in
                    EntryConfigurableSeatCard(
                        seat: seat,
                        title: configuration.label(for: seat.id),
                        palette: palette,
                        onDifficultyChange: { difficulty in
                            configuration.setBotDifficulty(
                                difficulty,
                                for: seat.id
                            )
                        },
                        onRemove: {
                            configuration.removeSeat(id: seat.id)
                        }
                    )
                }

                ForEach(
                    0..<configuration.openSeatCount,
                    id: \.self
                ) { offset in
                    EntryReservedSeatCard(
                        seatNumber:
                            configuration.totalPlayerCount + offset + 1,
                        palette: palette
                    )
                }
            }
            .frame(height: 240, alignment: .top)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                EntryAddSeatButton(
                    title: "Add Human",
                    systemImage: "person.badge.plus",
                    palette: palette
                ) {
                    configuration.addSeat(kind: .human)
                }

                EntryAddSeatButton(
                    title: "Add Bot",
                    systemImage: "cpu",
                    palette: palette
                ) {
                    configuration.addSeat(kind: .bot)
                }
            }
            .frame(maxWidth: 560)
            .disabled(!configuration.canAddSeat)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(invitationSummary)
                        .font(.subheadline.weight(.semibold))
                    Text(
                        supportingMessage
                    )
                    .font(.caption)
                    .foregroundStyle(palette.muted)
                }

                Spacer()

                Button(action: onStart) {
                    Label(actionTitle, systemImage: actionSystemImage)
                }
                .buttonStyle(EntryPrimaryButtonStyle(
                    fill: palette.accent,
                    foreground: palette.background
                ))
                .disabled(!configuration.canStart)
                .accessibilityIdentifier("start-family-table")
            }
        }
        .foregroundStyle(palette.text)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(palette.panel.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(palette.muted.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private var invitationSummary: String {
        if configuration.seats.isEmpty {
            return "Your table is waiting for company"
        }
        if configuration.invitedHumanCount > 0,
           !isGameCenterAuthenticated {
            return "Sign in to invite "
                + "\(configuration.invitedHumanCount) "
                + (configuration.invitedHumanCount == 1
                    ? "guest"
                    : "guests")
        }
        if configuration.invitedHumanCount == 0 {
            return "\(configuration.botCount) house "
                + (configuration.botCount == 1 ? "player is" : "players are")
                + " ready"
        }
        return "\(configuration.invitedHumanCount) "
            + (configuration.invitedHumanCount == 1
                ? "invitation is"
                : "invitations are")
            + " ready to send"
    }

    private var supportingMessage: String {
        if configuration.seats.isEmpty {
            return "Add a person or a house player to continue."
        }
        if configuration.invitedHumanCount > 0,
           !isGameCenterAuthenticated {
            if configuration.botCount > 0 {
                return "\(configuration.botCount) house "
                    + (configuration.botCount == 1
                        ? "player is"
                        : "players are")
                    + " ready immediately."
            }
            return "Game Center opens after the table is confirmed."
        }
        if configuration.invitedHumanCount == 0 {
            return "No sign-in is required for a bot-only table."
        }
        return "Game Center opens for exactly the selected guests."
    }
}

private struct EntryHostSeatCard: View {
    let localPlayerName: String
    let palette: EntryFinalistPalette

    var body: some View {
        HStack(spacing: 11) {
            EntryAvatar(
                text: "Y",
                fill: palette.accent,
                foreground: palette.background
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("You")
                    .font(.subheadline.weight(.bold))
                Text(hostSubtitle)
                    .font(.caption)
                    .foregroundStyle(palette.muted)
            }

            Spacer()

            Text("HOST")
                .font(.caption2.weight(.black))
                .tracking(1.2)
                .foregroundStyle(palette.gold)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(palette.panelStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(palette.gold, lineWidth: 1.5)
                )
        )
    }

    private var hostSubtitle: String {
        localPlayerName.isEmpty
            ? "This iPad"
            : "\(localPlayerName) - this iPad"
    }
}

private struct EntryConfigurableSeatCard: View {
    let seat: FamilyTableSeat
    let title: String
    let palette: EntryFinalistPalette
    let onDifficultyChange: (BotDifficulty) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            EntryAvatar(
                text: seat.kind == .human ? "H" : "B",
                fill: seat.kind == .human ? palette.accent : palette.gold,
                foreground: palette.background
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                if seat.kind == .human {
                    Text("Game Center invite")
                        .font(.caption)
                        .foregroundStyle(palette.muted)
                } else {
                    EntryBotDifficultyMenu(
                        title: title,
                        selection: seat.botDifficulty ?? .hard,
                        palette: palette,
                        onChange: onDifficultyChange
                    )
                }
            }

            Spacer(minLength: 4)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(palette.muted)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(title)")
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(palette.panelStrong.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(palette.muted.opacity(0.22), lineWidth: 1)
                )
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            seat.kind == .human
                                ? palette.accent
                                : palette.gold
                        )
                        .frame(width: 3)
                        .padding(.vertical, 12)
                }
        )
    }
}

private struct EntryBotDifficultyMenu: View {
    let title: String
    let selection: BotDifficulty
    let palette: EntryFinalistPalette
    let onChange: (BotDifficulty) -> Void

    var body: some View {
        Menu {
            ForEach(BotDifficulty.allCases, id: \.self) { difficulty in
                Button {
                    onChange(difficulty)
                } label: {
                    if difficulty == selection {
                        Label(difficulty.displayName, systemImage: "checkmark")
                    } else {
                        Text(difficulty.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.displayName.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .black))
            }
            .foregroundStyle(palette.gold)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(title) strength, \(selection.displayName)"
        )
        .accessibilityIdentifier(
            title.lowercased().replacingOccurrences(of: " ", with: "-")
                + "-difficulty"
        )
    }
}

private struct EntryReservedSeatCard: View {
    let seatNumber: Int
    let palette: EntryFinalistPalette

    var body: some View {
        VStack(spacing: 4) {
            Text("RESERVED SEAT \(seatNumber)")
                .font(.caption2.weight(.black))
                .tracking(1.2)
                .foregroundStyle(palette.muted)
            Text("Waiting at the table")
                .font(.caption2)
                .foregroundStyle(palette.muted.opacity(0.76))
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(palette.panelStrong.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(
                            palette.muted.opacity(0.24),
                            style: StrokeStyle(
                                lineWidth: 1,
                                dash: [5, 5]
                            )
                        )
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reserved seat \(seatNumber), empty")
        .accessibilityIdentifier("reserved-family-seat-\(seatNumber)")
    }
}

private struct EntryAddSeatButton: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let systemImage: String
    let palette: EntryFinalistPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? palette.accent : palette.muted)
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(
                    (isEnabled ? palette.accent : palette.muted)
                        .opacity(isEnabled ? 0.08 : 0.05)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(
                            (
                                isEnabled ? palette.accent : palette.muted
                            ).opacity(isEnabled ? 0.55 : 0.24),
                            style: StrokeStyle(
                                lineWidth: 1.2,
                                dash: [6, 5]
                            )
                        )
                )
        )
        .accessibilityIdentifier(
            title == "Add Human"
                ? "add-family-human"
                : "add-family-bot"
        )
    }
}

private struct EntryAvatar: View {
    let text: String
    let fill: Color
    let foreground: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.black))
            .foregroundStyle(foreground)
            .frame(width: 36, height: 36)
            .background(Circle().fill(fill))
    }
}

private struct EntryCountMetric: View {
    let value: Int
    let label: String
    let palette: EntryFinalistPalette

    var body: some View {
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
}

private struct EntryDossierDetail: View {
    let label: String
    let value: String
    let detail: String
    let palette: EntryFinalistPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label.uppercased())
                .font(.caption2.weight(.black))
                .tracking(1.1)
                .foregroundStyle(palette.muted)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(detail)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 13)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.muted.opacity(0.20))
                .frame(height: 1)
        }
    }
}

private struct EntryOccupancyDots: View {
    let occupiedCount: Int
    let palette: EntryFinalistPalette

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<RulesConfig.maxPlayers, id: \.self) { index in
                Circle()
                    .fill(
                        index < occupiedCount
                            ? palette.accent
                            : palette.panelStrong
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                index < occupiedCount
                                    ? palette.accent
                                    : palette.muted.opacity(0.52),
                                lineWidth: 1
                            )
                    )
                    .frame(width: 9, height: 9)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(occupiedCount) of \(RulesConfig.maxPlayers) seats occupied"
        )
        .accessibilityIdentifier("family-table-occupancy")
    }
}

private struct DecoCardShowpiece: View {
    let palette: EntryFinalistPalette

    var body: some View {
        ZStack {
            ChamferedRectangle(corner: 44)
                .fill(palette.panel.opacity(0.75))
                .overlay(
                    ChamferedRectangle(corner: 44)
                        .stroke(palette.gold, lineWidth: 2)
                )
                .rotationEffect(.degrees(45))
                .frame(width: 270, height: 270)

            ChamferedRectangle(corner: 34)
                .stroke(palette.accent.opacity(0.62), lineWidth: 2)
                .rotationEffect(.degrees(45))
                .frame(width: 208, height: 208)

            HStack(spacing: -30) {
                EntryPlayingCard(
                    rank: "A",
                    suit: "spade.fill",
                    color: palette.background,
                    palette: palette
                )
                .rotationEffect(.degrees(-14))
                .offset(y: 20)

                EntryPlayingCard(
                    rank: "7",
                    suit: "heart.fill",
                    color: palette.accent,
                    palette: palette
                )
                .zIndex(2)

                EntryPlayingCard(
                    rank: "J",
                    suit: "club.fill",
                    color: palette.background,
                    palette: palette
                )
                .rotationEffect(.degrees(14))
                .offset(y: 20)
            }

            VStack(spacing: 3) {
                Text("TONIGHT'S TABLE")
                    .font(.caption2.weight(.black))
                    .tracking(1.8)
                Text("2-6 PLAYERS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(palette.muted)
            }
            .foregroundStyle(palette.gold)
            .offset(y: 142)
        }
    }
}

private struct EntryPlayingCard: View {
    let rank: String
    let suit: String
    let color: Color
    let palette: EntryFinalistPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rank)
                .font(.title2.weight(.black))
            Image(systemName: suit)
                .font(.title2)
            Spacer()
            Image(systemName: suit)
                .font(.title3)
                .rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .foregroundStyle(color)
        .padding(12)
        .frame(width: 104, height: 146)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.text)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(palette.gold.opacity(0.52), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 10, y: 8)
        )
    }
}

private struct MidnightDecoBackdrop: View {
    let palette: EntryFinalistPalette

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        palette.background,
                        palette.backgroundSecondary,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Canvas { context, size in
                    let spacing: CGFloat = 38
                    var offset = -size.height
                    while offset < size.width {
                        var path = Path()
                        path.move(to: CGPoint(x: offset, y: 0))
                        path.addLine(to: CGPoint(
                            x: offset + size.height,
                            y: size.height
                        ))
                        context.stroke(
                            path,
                            with: .color(palette.accent.opacity(0.055)),
                            lineWidth: 1
                        )
                        offset += spacing
                    }
                }

                ChamferedRectangle(corner: 52)
                    .stroke(palette.gold.opacity(0.68), lineWidth: 2)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 26)

                ChamferedRectangle(corner: 46)
                    .stroke(palette.accent.opacity(0.28), lineWidth: 1)
                    .padding(.horizontal, 44)
                    .padding(.vertical, 36)

                Circle()
                    .fill(palette.accent.opacity(0.08))
                    .frame(
                        width: proxy.size.width * 0.55,
                        height: proxy.size.width * 0.55
                    )
                    .blur(radius: 35)
                    .offset(
                        x: proxy.size.width * 0.34,
                        y: proxy.size.height * 0.24
                    )
            }
        }
    }
}

private struct BundAfterDarkBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let palette: EntryFinalistPalette

    var body: some View {
        TimelineView(
            .animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)
        ) { timeline in
            GeometryReader { proxy in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                let nearDrift = CGFloat(sin(phase / 17)) * 3
                let farDrift = CGFloat(sin(phase / 23)) * -5
                let glowPulse = 1 + CGFloat(sin(phase / 4.5)) * 0.025

                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: [
                            palette.background,
                            palette.backgroundSecondary,
                            palette.background,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Ellipse()
                        .fill(palette.accent.opacity(0.10))
                        .frame(
                            width: proxy.size.width * 0.46,
                            height: proxy.size.height * 0.34
                        )
                        .blur(radius: 26)
                        .scaleEffect(glowPulse)
                        .offset(
                            x: proxy.size.width * 0.29,
                            y: -proxy.size.height * 0.24
                        )

                    BundNightLights(
                        palette: palette,
                        phase: phase
                    )
                    .frame(height: proxy.size.height * 0.58)
                    .opacity(reduceMotion ? 0.72 : 1)

                    BundSkyline(palette: palette)
                        .frame(height: proxy.size.height * 0.38)
                        .scaleEffect(
                            x: 1.08,
                            y: 0.76,
                            anchor: .bottom
                        )
                        .offset(x: farDrift, y: -18)
                        .opacity(0.22)

                    BundSkyline(palette: palette)
                        .frame(height: proxy.size.height * 0.42)
                        .offset(x: nearDrift)

                    BundRiver(palette: palette, phase: phase)
                        .frame(height: proxy.size.height * 0.18)
                }
            }
        }
    }
}

private struct BundNightLights: View {
    let palette: EntryFinalistPalette
    let phase: TimeInterval

    var body: some View {
        Canvas { context, size in
            for index in 0..<18 {
                let column = CGFloat((index * 37) % 101) / 100
                let row = CGFloat((index * 53) % 83) / 100
                let twinkle = (
                    sin(phase * 0.55 + Double(index) * 0.83) + 1
                ) / 2
                let diameter = CGFloat(1.5 + twinkle * 1.8)
                let x = size.width * column
                let y = size.height * (0.10 + row * 0.72)
                let rect = CGRect(
                    x: x - diameter / 2,
                    y: y - diameter / 2,
                    width: diameter,
                    height: diameter
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(
                        palette.gold.opacity(0.10 + twinkle * 0.34)
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct BundSkyline: View {
    let palette: EntryFinalistPalette
    private let heights: [CGFloat] = [
        0.38, 0.58, 0.46, 0.72, 0.53, 0.88,
        0.62, 0.49, 0.79, 0.57, 0.68, 0.43,
    ]

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(heights.enumerated()), id: \.offset) { item in
                    BundBuilding(
                        height: proxy.size.height * item.element,
                        width: buildingWidth(
                            index: item.offset,
                            totalWidth: proxy.size.width
                        ),
                        palette: palette,
                        crown: item.offset == 5
                    )
                }
            }
            .padding(.horizontal, 32)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(palette.gold.opacity(0.85))
                    .frame(height: 2)
            }
        }
    }

    private func buildingWidth(index: Int, totalWidth: CGFloat) -> CGFloat {
        let base = totalWidth / 16
        return index.isMultiple(of: 3) ? base * 1.2 : base
    }
}

private struct BundBuilding: View {
    let height: CGFloat
    let width: CGFloat
    let palette: EntryFinalistPalette
    let crown: Bool

    var body: some View {
        VStack(spacing: 0) {
            if crown {
                Triangle()
                    .fill(palette.gold.opacity(0.75))
                    .frame(width: width * 0.62, height: 22)
            }

            VStack(spacing: 11) {
                ForEach(0..<5, id: \.self) { _ in
                    HStack(spacing: 7) {
                        Capsule()
                            .fill(palette.gold.opacity(0.72))
                            .frame(width: 8, height: 3)
                        Capsule()
                            .fill(palette.gold.opacity(0.48))
                            .frame(width: 8, height: 3)
                    }
                }
            }
            .frame(width: width, height: height)
            .background(
                LinearGradient(
                    colors: [
                        palette.panelStrong.opacity(0.96),
                        palette.panel.opacity(0.92),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                Rectangle()
                    .stroke(palette.muted.opacity(0.28), lineWidth: 1)
            )
        }
    }
}

private struct BundRiver: View {
    let palette: EntryFinalistPalette
    let phase: TimeInterval

    var body: some View {
        Canvas { context, size in
            var background = Path()
            background.addRect(CGRect(origin: .zero, size: size))
            context.fill(
                background,
                with: .linearGradient(
                    Gradient(colors: [
                        palette.background.opacity(0.88),
                        palette.panel.opacity(0.96),
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            for index in 0..<11 {
                let y = CGFloat(index) * 17 + 8
                let shimmer = (
                    sin(phase * 0.42 + Double(index) * 0.72) + 1
                ) / 2
                let drift = CGFloat(
                    sin(phase * 0.18 + Double(index) * 0.51)
                ) * 14
                var path = Path()
                path.move(to: CGPoint(x: -50 + drift, y: y))
                path.addLine(to: CGPoint(
                    x: size.width * 0.30 + drift,
                    y: y - 8
                ))
                path.move(to: CGPoint(
                    x: size.width * 0.38 - drift * 0.35,
                    y: y + 2
                ))
                path.addLine(to: CGPoint(
                    x: size.width * 0.66 - drift * 0.35,
                    y: y - 10
                ))
                path.move(to: CGPoint(
                    x: size.width * 0.74 + drift * 0.55,
                    y: y - 3
                ))
                path.addLine(to: CGPoint(
                    x: size.width + 50 + drift * 0.55,
                    y: y - 12
                ))
                context.stroke(
                    path,
                    with: .color(
                        index.isMultiple(of: 2)
                            ? palette.accent.opacity(0.15 + shimmer * 0.15)
                            : palette.gold.opacity(0.12 + shimmer * 0.13)
                    ),
                    lineWidth: 2
                )
            }
        }
    }
}

private struct EntryPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let fill: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.black))
            .foregroundStyle(
                foreground.opacity(isEnabled ? 1 : 0.48)
            )
            .padding(.horizontal, 24)
            .frame(minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        fill.opacity(
                            isEnabled
                                ? (configuration.isPressed ? 0.78 : 1)
                                : 0.24
                        )
                    )
                    .shadow(
                        color: fill.opacity(isEnabled ? 0.30 : 0),
                        radius: configuration.isPressed && isEnabled ? 4 : 11,
                        y: 5
                    )
            )
            .scaleEffect(
                configuration.isPressed && isEnabled ? 0.98 : 1
            )
    }
}

private struct EntrySecondaryButtonStyle: ButtonStyle {
    let foreground: Color
    let stroke: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 22)
            .frame(minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(stroke.opacity(0.55), lineWidth: 1.2)
                    )
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct ChamferedRectangle: Shape {
    let corner: CGFloat

    func path(in rect: CGRect) -> Path {
        let amount = min(corner, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + amount, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - amount, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + amount))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - amount))
        path.addLine(to: CGPoint(x: rect.maxX - amount, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + amount, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - amount))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + amount))
        path.closeSubpath()
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Midnight Deco") {
    EntryFinalistPreviewHost(design: .midnightDeco, screen: .home)
}

#Preview("Bund After Dark") {
    EntryFinalistPreviewHost(design: .bundAfterDark, screen: .home)
}
