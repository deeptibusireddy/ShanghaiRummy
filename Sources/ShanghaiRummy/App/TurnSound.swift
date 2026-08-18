import AVFAudio
import Foundation
import OSLog

enum TurnNotificationSound: String, CaseIterable, Identifiable {
    case classic
    case crystal
    case softBell = "soft-bell"
    case woodblock

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic:
            return "Classic Chime"
        case .crystal:
            return "Crystal"
        case .softBell:
            return "Soft Bell"
        case .woodblock:
            return "Woodblock"
        }
    }

    var detail: String {
        switch self {
        case .classic:
            return "The original quick two-note cue"
        case .crystal:
            return "Bright and easy to notice"
        case .softBell:
            return "Warm with a gentle decay"
        case .woodblock:
            return "Short, dry, and unobtrusive"
        }
    }

    var resourceName: String {
        switch self {
        case .classic:
            return "turn-chime"
        case .crystal:
            return "turn-crystal"
        case .softBell:
            return "turn-soft-bell"
        case .woodblock:
            return "turn-woodblock"
        }
    }

    var symbolName: String {
        switch self {
        case .classic:
            return "music.note"
        case .crystal:
            return "sparkles"
        case .softBell:
            return "bell.fill"
        case .woodblock:
            return "circle.grid.cross.fill"
        }
    }
}

enum TurnSoundPreferences {
    static let enabledKey = "settings.turnSoundsEnabled"
    static let selectedSoundKey = "settings.turnNotificationSound"

    static func soundsEnabled(
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard defaults.object(forKey: enabledKey) != nil else {
            return true
        }
        return defaults.bool(forKey: enabledKey)
    }

    static func selectedSound(
        defaults: UserDefaults = .standard
    ) -> TurnNotificationSound {
        guard let rawValue = defaults.string(forKey: selectedSoundKey),
              let sound = TurnNotificationSound(rawValue: rawValue) else {
            return .classic
        }
        return sound
    }
}

@MainActor
final class TurnSoundPlayer {
    static let shared = TurnSoundPlayer()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier
            ?? "com.deeptibusireddy.ShanghaiRummy",
        category: "TurnSound"
    )
    private var player: AVAudioPlayer?
    private var hasConfiguredAudioSession = false

    private init() {}

    @discardableResult
    func play(
        _ sound: TurnNotificationSound,
        bundle: Bundle = .main
    ) -> Bool {
        guard let url = Self.resourceURL(for: sound, bundle: bundle) else {
            logger.error(
                "Missing turn sound resource: \(sound.resourceName, privacy: .public).wav"
            )
            return false
        }

        do {
            try activateAudioSession()
            player?.stop()
            let nextPlayer = try AVAudioPlayer(contentsOf: url)
            nextPlayer.volume = 1
            nextPlayer.prepareToPlay()
            player = nextPlayer
            return nextPlayer.play()
        } catch {
            logger.error(
                "Unable to play \(sound.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    static func resourceURL(
        for sound: TurnNotificationSound,
        bundle: Bundle
    ) -> URL? {
        bundle.url(
            forResource: sound.resourceName,
            withExtension: "wav"
        )
    }

    private func activateAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        if !hasConfiguredAudioSession {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            hasConfiguredAudioSession = true
        }
        try session.setActive(true)
    }
}
