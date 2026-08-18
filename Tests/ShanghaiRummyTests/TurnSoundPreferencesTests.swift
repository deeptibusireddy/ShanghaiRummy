import XCTest
@testable import ShanghaiRummy

@MainActor
final class TurnSoundPreferencesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "TurnSoundPreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testPreferencesDefaultToEnabledClassicChime() {
        XCTAssertTrue(
            TurnSoundPreferences.soundsEnabled(defaults: defaults)
        )
        XCTAssertEqual(
            TurnSoundPreferences.selectedSound(defaults: defaults),
            .classic
        )
    }

    func testPreferencesRestoreStoredToggleAndSelection() {
        defaults.set(false, forKey: TurnSoundPreferences.enabledKey)
        defaults.set(
            TurnNotificationSound.crystal.rawValue,
            forKey: TurnSoundPreferences.selectedSoundKey
        )

        XCTAssertFalse(
            TurnSoundPreferences.soundsEnabled(defaults: defaults)
        )
        XCTAssertEqual(
            TurnSoundPreferences.selectedSound(defaults: defaults),
            .crystal
        )
    }

    func testUnknownStoredSoundFallsBackToClassic() {
        defaults.set(
            "missing-tone",
            forKey: TurnSoundPreferences.selectedSoundKey
        )

        XCTAssertEqual(
            TurnSoundPreferences.selectedSound(defaults: defaults),
            .classic
        )
    }

    func testEveryTurnSoundHasAUniqueBundledWaveFile() {
        let sounds = TurnNotificationSound.allCases
        XCTAssertEqual(
            Set(sounds.map(\.resourceName)).count,
            sounds.count
        )

        for sound in sounds {
            XCTAssertNotNil(
                TurnSoundPlayer.resourceURL(
                    for: sound,
                    bundle: .main
                ),
                "Missing bundled audio for \(sound.displayName)"
            )
        }
    }
}
