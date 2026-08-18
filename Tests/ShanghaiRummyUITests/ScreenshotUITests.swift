import XCTest
import UIKit

/// UI tests whose only job is to walk the app and capture screenshots at each
/// key screen. CI extracts these screenshots from the .xcresult bundle and
/// uploads them as an artifact — so the developer can preview the app from
/// Windows without a Mac.
///
/// Demo launch arguments provide deterministic mid-game, staging, and scoring
/// states without depending on coordinate-driven SpriteKit interactions.
final class ScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments += ["--ui-testing"]
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
        }
        app = nil
    }

    func testCaptureScreens() throws {
        app.launch()

        snapshot(named: "01-home-menu")

        let createTable = app.buttons["create-table"]
        XCTAssertTrue(
            createTable.waitForExistence(timeout: 5),
            "Home menu should show the unified Create Table button"
        )
        XCTAssertTrue(app.staticTexts["THE SUPPER CLUB IS OPEN"].exists)
        XCTAssertTrue(app.buttons["sign-in-game-center"].exists)
        XCTAssertFalse(app.buttons["Hot-Seat (Pass & Play)"].exists)
        XCTAssertFalse(app.buttons["Quick Pair (2-Player Beta Test)"].exists)
        createTable.tap()

        XCTAssertTrue(
            app.buttons["start-family-table"].waitForExistence(timeout: 5)
        )
        snapshot(named: "02-create-table-setup")

        app.buttons["add-family-bot"].tap()
        let start = app.buttons["start-family-table"]
        XCTAssertTrue(start.waitForExistence(timeout: 2))
        XCTAssertTrue(start.isEnabled)
        start.tap()

        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["opening-seat-draw"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["DRAW FOR SEATS"].exists)
        Thread.sleep(forTimeInterval: 0.8)
        snapshot(named: "03-opening-seat-draw")

        let takeSeats = app.buttons["opening-seat-draw-continue"]
        XCTAssertTrue(takeSeats.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["THE TABLE IS SET"].exists)
        snapshot(named: "03-clockwise-seating")
        takeSeats.tap()

        XCTAssertTrue(app.staticTexts["Your Draw"].waitForExistence(timeout: 5))
        // Small pause so the scene finishes its first frame.
        Thread.sleep(forTimeInterval: 0.5)
        snapshot(named: "04-hand-1-scaffold")
    }

    func testCaptureFamilyTableSetup() throws {
        app.launchArguments += ["--demo-family-table-setup"]
        app.launch()

        XCTAssertTrue(
            app.buttons["start-family-table"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["You"].exists)
        XCTAssertFalse(app.staticTexts["Bot 1"].exists)
        for seatNumber in 2...6 {
            XCTAssertTrue(
                app.descendants(matching: .any)[
                    "reserved-family-seat-\(seatNumber)"
                ].exists
            )
        }
        let start = app.buttons["start-family-table"]
        XCTAssertTrue(start.exists)
        XCTAssertFalse(start.isEnabled)
        snapshot(named: "02-family-table-setup")

        let addHuman = app.buttons["add-family-human"]
        let addBot = app.buttons["add-family-bot"]
        XCTAssertTrue(addHuman.exists)
        XCTAssertTrue(addBot.exists)
        let initialHumanFrame = addHuman.frame
        let initialBotFrame = addBot.frame
        XCTAssertTrue(app.staticTexts["1 of 6 seated"].exists)
        addHuman.tap()
        XCTAssertTrue(app.staticTexts["Human 1"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["2 of 6 seated"].exists)
        XCTAssertTrue(app.buttons["Remove Human 1"].exists)
        XCTAssertFalse(app.buttons["Human"].exists)
        XCTAssertFalse(app.buttons["Bot"].exists)
        XCTAssertFalse(
            app.descendants(matching: .any)["reserved-family-seat-2"].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["reserved-family-seat-3"].exists
        )
        XCTAssertEqual(addHuman.frame.midX, initialHumanFrame.midX, accuracy: 1)
        XCTAssertEqual(addHuman.frame.midY, initialHumanFrame.midY, accuracy: 1)
        XCTAssertEqual(addBot.frame.midX, initialBotFrame.midX, accuracy: 1)
        XCTAssertEqual(addBot.frame.midY, initialBotFrame.midY, accuracy: 1)
        XCTAssertTrue(start.isEnabled)
        XCTAssertEqual(start.label, "Sign In & Invite 1 Guest")
        snapshot(named: "02-family-table-one-human")
        app.buttons["Remove Human 1"].tap()
        XCTAssertFalse(start.isEnabled)

        addBot.tap()
        XCTAssertTrue(app.staticTexts["Bot 1"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Remove Bot 1"].exists)
        let botDifficulty = app.buttons["bot-1-difficulty"]
        XCTAssertTrue(botDifficulty.exists)
        XCTAssertTrue(botDifficulty.label.contains("Hard"))
        botDifficulty.tap()
        let medium = app.buttons["Medium"]
        XCTAssertTrue(medium.waitForExistence(timeout: 2))
        medium.tap()
        XCTAssertTrue(botDifficulty.label.contains("Medium"))
        XCTAssertTrue(start.isEnabled)
        for botNumber in 2...5 {
            addBot.tap()
            XCTAssertTrue(
                app.staticTexts["Bot \(botNumber)"]
                    .waitForExistence(timeout: 2)
            )
        }
        XCTAssertTrue(app.staticTexts["6 of 6 seated"].exists)
        for seatNumber in 2...6 {
            XCTAssertFalse(
                app.descendants(matching: .any)[
                    "reserved-family-seat-\(seatNumber)"
                ].exists
            )
        }
        XCTAssertFalse(addHuman.isEnabled)
        XCTAssertFalse(addBot.isEnabled)
        XCTAssertEqual(addHuman.frame.midX, initialHumanFrame.midX, accuracy: 1)
        XCTAssertEqual(addHuman.frame.midY, initialHumanFrame.midY, accuracy: 1)
        XCTAssertEqual(addBot.frame.midX, initialBotFrame.midX, accuracy: 1)
        XCTAssertEqual(addBot.frame.midY, initialBotFrame.midY, accuracy: 1)
        snapshot(named: "02-family-table-full")
        start.tap()
        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
    }

    func testQuitRequiresConfirmation() throws {
        app.launch()

        let createTable = app.buttons["create-table"]
        XCTAssertTrue(createTable.waitForExistence(timeout: 5))
        createTable.tap()
        XCTAssertTrue(
            app.buttons["start-family-table"].waitForExistence(timeout: 5)
        )
        app.buttons["add-family-bot"].tap()
        app.buttons["start-family-table"].tap()

        let quit = app.buttons["quit-game"]
        XCTAssertTrue(quit.waitForExistence(timeout: 5))
        let takeSeats = app.buttons["opening-seat-draw-continue"]
        XCTAssertTrue(takeSeats.waitForExistence(timeout: 5))
        takeSeats.tap()
        tapCenter(of: quit)

        let alert = app.alerts["Leave Game?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        XCTAssertTrue(alert.buttons["Keep Playing"].exists)
        XCTAssertTrue(alert.buttons["Leave Game"].exists)
        XCTAssertFalse(createTable.exists)

        alert.buttons["Keep Playing"].tap()
        XCTAssertTrue(quit.waitForExistence(timeout: 2))

        tapCenter(of: quit)
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.buttons["Leave Game"].tap()
        XCTAssertTrue(createTable.waitForExistence(timeout: 5))
    }

    func testTurnSoundSettingsOfferPreviewsAndPersistentToggle() throws {
        app.launch()

        let soundSettings = app.buttons["home-turn-sound-settings"]
        XCTAssertTrue(soundSettings.waitForExistence(timeout: 5))
        soundSettings.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["turn-sound-settings-view"]
                .waitForExistence(timeout: 3)
        )
        let enabledToggle = app.switches["turn-sounds-enabled"]
        XCTAssertTrue(enabledToggle.exists)

        for sound in ["classic", "crystal", "soft-bell", "woodblock"] {
            XCTAssertTrue(app.buttons["turn-sound-\(sound)"].exists)
        }

        app.buttons["turn-sound-crystal"].tap()
        dismissSoundUnavailableAlertIfNeeded()
        setSwitch(enabledToggle, enabled: false)
        setSwitch(enabledToggle, enabled: true)
        dismissSoundUnavailableAlertIfNeeded()

        app.buttons["close-turn-sound-settings"].tap()
        XCTAssertTrue(soundSettings.waitForExistence(timeout: 3))
    }

    private func dismissSoundUnavailableAlertIfNeeded() {
        let alert = app.alerts["Sound Unavailable"]
        if alert.waitForExistence(timeout: 0.5) {
            alert.buttons["OK"].tap()
        }
    }

    private func setSwitch(
        _ element: XCUIElement,
        enabled: Bool
    ) {
        let expectedValue = enabled ? "1" : "0"
        if element.value as? String != expectedValue {
            element.coordinate(
                withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)
            )
            .tap()
        }
        let deadline = Date().addingTimeInterval(2)
        while element.value as? String != expectedValue,
              Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertEqual(
            element.value as? String,
            expectedValue
        )
    }

    func testCaptureMidGamePreview() throws {
        // Boots directly into a rigged 4-player mid-game state so we can
        // preview the table populated with melds from every player.
        app.launchArguments += ["--demo-mid-game"]
        app.launch()
        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.7)
        snapshot(named: "04-mid-game-game-night")
    }

    func testCapturePacedBotTurn() throws {
        app.launchArguments += ["--demo-bot-turn"]
        app.launch()

        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.7)
        snapshot(named: "04-bot-turn-progress")
    }

    func testCaptureFourPlayerBuyDecision() throws {
        app.launchArguments += ["--demo-mid-game", "--demo-buy-decision"]
        app.launch()

        let title = app.staticTexts["Buy Opportunity"]
        let buysLeft = app.staticTexts["BUYS LEFT: 2"]
        let accept = app.buttons["accept-buy-offer"]
        let pass = app.buttons["pass-buy-offer"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(buysLeft.waitForExistence(timeout: 5))
        XCTAssertTrue(accept.waitForExistence(timeout: 5))
        XCTAssertTrue(pass.waitForExistence(timeout: 5))
        XCTAssertEqual(
            accept.label,
            "Buy king of hearts plus 1 penalty card"
        )
        XCTAssertEqual(pass.label, "Pass")
        let contentMinX = min(
            title.frame.minX,
            min(buysLeft.frame.minX, min(accept.frame.minX, pass.frame.minX))
        )
        let contentMaxX = max(
            title.frame.maxX,
            max(buysLeft.frame.maxX, max(accept.frame.maxX, pass.frame.maxX))
        )
        XCTAssertLessThanOrEqual(contentMaxX - contentMinX + 28, 228)
        Thread.sleep(forTimeInterval: 0.7)
        snapshot(named: "04-four-player-buy-decision")
    }

    func testCaptureSixPlayerStatusLayout() throws {
        app.launchArguments += ["--demo-six-player-status"]
        app.launch()

        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.7)
        snapshot(named: "04-six-player-status")
    }

    func testCaptureSixPlayerScorecard() throws {
        app.launchArguments += [
            "--demo-six-player-status",
            "--demo-scorecard",
        ]
        app.launch()

        let scorecard = app.descendants(matching: .any)["live-scorecard"]
        XCTAssertTrue(scorecard.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current Score"].exists)
        XCTAssertTrue(app.staticTexts["Morgan"].exists)
        Thread.sleep(forTimeInterval: 0.5)
        snapshot(named: "04-six-player-scorecard")
    }

    func testCaptureMidGameCasinoFelt() throws {
        app.launchArguments += ["--demo-mid-game", "--theme-felt"]
        app.launch()
        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.7)
        snapshot(named: "05-mid-game-casino-felt")
    }

    func testCaptureMidGameMinimalModern() throws {
        app.launchArguments += ["--demo-mid-game", "--theme-minimal"]
        app.launch()
        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.7)
        snapshot(named: "06-mid-game-minimal-modern")
    }

    func testCaptureStagingTray() throws {
        app.launchArguments += [
            "--demo-mid-game",
            "--demo-stage-long-sequence",
        ]
        app.launch()
        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.9)
        snapshot(named: "07-staging-tray-long-sequence")
    }

    func testCaptureCrowdedNewCardMarkers() throws {
        app.launchArguments += ["--demo-crowded-new-cards"]
        app.launch()
        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.9)
        snapshot(named: "07-crowded-new-card-markers")
    }

    func testCaptureHandOver() throws {
        app.launchArguments += ["--demo-hand-over"]
        app.launch()
        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.9)
        snapshot(named: "08-hand-over-scoreboard")
    }

    func testCaptureGameOver() throws {
        app.launchArguments += ["--demo-game-over"]
        app.launch()

        let celebration = app.descendants(matching: .any)[
            "game-over-celebration"
        ]
        XCTAssertTrue(celebration.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Tonight's Champion"].exists)
        XCTAssertTrue(app.staticTexts["You"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["podium-place-1"].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["podium-place-2"].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["podium-place-3"].exists
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["final-standing-4"].exists
        )
        XCTAssertTrue(app.buttons["game-over-back-to-menu"].exists)
        XCTAssertFalse(app.buttons["Deal Next Hand"].isHittable)
        XCTAssertFalse(app.buttons["quit-game"].isHittable)
        Thread.sleep(forTimeInterval: 0.9)
        snapshot(named: "09-game-over-final")
    }

    func testCaptureIPadLayout() throws {
        XCTAssertEqual(
            UIDevice.current.userInterfaceIdiom,
            .pad,
            "The iPad-only target must run on an iPad simulator"
        )

        app.launchArguments += ["--demo-mid-game"]
        app.launch()

        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 2))
        XCTAssertLessThan(
            window.frame.width / window.frame.height,
            1.8,
            "The iPad should use its native canvas, not a zoomed iPhone viewport"
        )
        Thread.sleep(forTimeInterval: 0.7)
        snapshot(named: "10-native-ipad-mid-game")
    }

    func testCaptureMidnightDecoHome() throws {
        launchEntryFinalist(design: "midnight-deco", screen: "home")
        snapshot(named: "11-midnight-deco-home-final")
    }

    func testCaptureMidnightDecoInvite() throws {
        launchEntryFinalist(design: "midnight-deco", screen: "invite")
        snapshot(named: "12-midnight-deco-invite-final")
    }

    func testCaptureBundAfterDarkHome() throws {
        launchEntryFinalist(design: "bund-after-dark", screen: "home")
        snapshot(named: "13-bund-after-dark-home-final")
    }

    func testCaptureBundAfterDarkInvite() throws {
        launchEntryFinalist(design: "bund-after-dark", screen: "invite")
        snapshot(named: "14-bund-after-dark-invite-final")
    }

    // MARK: - Helpers

    private func launchEntryFinalist(design: String, screen: String) {
        app.launchArguments += [
            "--demo-entry-finalist",
            "--entry-finalist-design",
            design,
            "--entry-finalist-screen",
            screen,
        ]
        app.launch()

        let preview = app.descendants(matching: .any)[
            "entry-finalist-\(design)-\(screen)"
        ]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.7)
    }

    private func snapshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapCenter(of element: XCUIElement) {
        let appFrame = app.frame
        let elementFrame = element.frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(
                dx: elementFrame.midX - appFrame.minX,
                dy: elementFrame.midY - appFrame.minY
            ))
            .tap()
    }
}
