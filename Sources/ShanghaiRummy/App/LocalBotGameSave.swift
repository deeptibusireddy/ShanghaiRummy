import Foundation

struct LocalBotGameSave: Codable, Equatable {
    static let currentFormatVersion = 1

    let formatVersion: Int
    let savedAt: Date
    let state: GameState
    let localPlayerId: UUID?
    let cpuPlayerDifficulties: [UUID: BotDifficulty]
    let handOrderByPlayer: [UUID: [UUID]]

    init(
        formatVersion: Int = LocalBotGameSave.currentFormatVersion,
        savedAt: Date,
        state: GameState,
        localPlayerId: UUID?,
        cpuPlayerDifficulties: [UUID: BotDifficulty],
        handOrderByPlayer: [UUID: [UUID]]
    ) {
        self.formatVersion = formatVersion
        self.savedAt = savedAt
        self.state = state
        self.localPlayerId = localPlayerId
        self.cpuPlayerDifficulties = cpuPlayerDifficulties
        self.handOrderByPlayer = handOrderByPlayer
    }

    var summary: LocalBotGameSaveSummary {
        let localPlayer = localPlayerId.flatMap { localId in
            state.players.first { $0.id == localId }
        }
        return LocalBotGameSaveSummary(
            savedAt: savedAt,
            playerCount: state.players.count,
            botCount: cpuPlayerDifficulties.count,
            currentHand: state.currentRound,
            localPlayerName: localPlayer?.name,
            localPlayerLevel: localPlayer?.currentLevel
        )
    }

    func belongs(to otherState: GameState) -> Bool {
        state.randomSeed == otherState.randomSeed
            && state.players.map(\.id) == otherState.players.map(\.id)
    }

    func validate() throws {
        guard formatVersion == Self.currentFormatVersion else {
            throw LocalBotGameSaveError.unsupportedFormat(formatVersion)
        }
        guard state.phase != .gameEnded else {
            throw LocalBotGameSaveError.invalidSave(
                "Completed games cannot be saved for resuming."
            )
        }

        let playerIds = Set(state.players.map(\.id))
        let botIds = Set(cpuPlayerDifficulties.keys)
        guard !botIds.isEmpty else {
            throw LocalBotGameSaveError.invalidSave(
                "Only local games with bots can be saved."
            )
        }
        guard botIds.isSubset(of: playerIds) else {
            throw LocalBotGameSaveError.invalidSave(
                "The saved bot roster does not match the table."
            )
        }
        if let localPlayerId {
            guard playerIds.contains(localPlayerId),
                  !botIds.contains(localPlayerId) else {
                throw LocalBotGameSaveError.invalidSave(
                    "The saved local player does not match the table."
                )
            }
        }

        for (playerId, order) in handOrderByPlayer {
            guard let player = state.players.first(where: {
                $0.id == playerId
            }) else {
                throw LocalBotGameSaveError.invalidSave(
                    "Saved hand ordering references an unknown player."
                )
            }
            let orderIds = Set(order)
            guard orderIds.count == order.count,
                  orderIds.isSubset(of: Set(player.hand.map(\.id))) else {
                throw LocalBotGameSaveError.invalidSave(
                    "Saved hand ordering does not match the cards in hand."
                )
            }
        }
    }
}

struct LocalBotGameSaveSummary: Equatable {
    let savedAt: Date
    let playerCount: Int
    let botCount: Int
    let currentHand: Int
    let localPlayerName: String?
    let localPlayerLevel: Int?
}

enum LocalBotGameSaveError: LocalizedError {
    case directoryUnavailable
    case unsupportedFormat(Int)
    case invalidSave(String)
    case readFailed(String)
    case writeFailed(String)
    case discardFailed(String)

    var errorDescription: String? {
        switch self {
        case .directoryUnavailable:
            return "The app could not locate its saved-game folder."
        case .unsupportedFormat(let version):
            return "This saved game uses unsupported format \(version)."
        case .invalidSave(let message):
            return message
        case .readFailed(let message):
            return "The saved game could not be read: \(message)"
        case .writeFailed(let message):
            return "The game could not be saved: \(message)"
        case .discardFailed(let message):
            return "The saved game could not be discarded: \(message)"
        }
    }
}

struct LocalBotGameSaveStore {
    private let fileManager: FileManager
    private let overrideFileURL: URL?

    init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        overrideFileURL = fileURL
        self.fileManager = fileManager
    }

    func load() throws -> LocalBotGameSave? {
        let url = try resolvedFileURL()
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw LocalBotGameSaveError.readFailed(
                error.localizedDescription
            )
        }

        let savedGame: LocalBotGameSave
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            savedGame = try decoder.decode(
                LocalBotGameSave.self,
                from: data
            )
        } catch {
            throw LocalBotGameSaveError.readFailed(
                error.localizedDescription
            )
        }
        try savedGame.validate()
        return savedGame
    }

    func save(_ savedGame: LocalBotGameSave) throws {
        try savedGame.validate()
        let url = try resolvedFileURL()

        do {
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(savedGame)
            try data.write(to: url, options: .atomic)
        } catch {
            throw LocalBotGameSaveError.writeFailed(
                error.localizedDescription
            )
        }
    }

    func discard() throws {
        let url = try resolvedFileURL()
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw LocalBotGameSaveError.discardFailed(
                error.localizedDescription
            )
        }
    }

    private func resolvedFileURL() throws -> URL {
        if let overrideFileURL {
            return overrideFileURL
        }
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw LocalBotGameSaveError.directoryUnavailable
        }
        return applicationSupport
            .appendingPathComponent(
                "ShanghaiRummyNights",
                isDirectory: true
            )
            .appendingPathComponent("SavedBotGame.json")
    }
}
