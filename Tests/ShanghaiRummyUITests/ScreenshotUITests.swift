import XCTest

/// UI tests whose only job is to walk the app and capture screenshots at each
/// key screen. CI extracts these screenshots from the .xcresult bundle and
/// uploads them as an artifact — so the developer can preview the app from
/// Windows without a Mac.
///
/// M2b note: game interactions (draw/discard) happen on SpriteKit nodes which
/// XCUITest can't identify by label without accessibility identifiers. We
/// therefore only screenshot the three navigable SwiftUI screens (home, setup,
/// game scaffold). Interaction screenshots (drawn card, pass-and-play) return
/// in M2d once we wire up accessibility identifiers on the sprites.
final class ScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    func testCaptureScreens() throws {
        let app = XCUIApplication()
        app.launch()

        snapshot(named: "01-home-menu")

        // Home → New Game setup
        let hotSeat = app.buttons["Hot-Seat (Pass & Play)"]
        XCTAssertTrue(hotSeat.waitForExistence(timeout: 5), "Home menu should show hot-seat button")
        hotSeat.tap()

        // Setup sheet appears
        _ = app.navigationBars["New Game"].waitForExistence(timeout: 5)
        snapshot(named: "02-new-game-setup")

        // Start the game with the default 2 players.
        app.buttons["Start"].tap()

        // Game container appears — nav bar shows "Hand 1". SpriteKit scene
        // paints the felt, piles, seats, and the current player's hand.
        _ = app.navigationBars["Hand 1"].waitForExistence(timeout: 5)
        // Small pause so the scene finishes its first frame.
        Thread.sleep(forTimeInterval: 0.5)
        snapshot(named: "03-hand-1-scaffold")
    }

    func testCaptureMidGamePreview() throws {
        // Boots directly into a rigged 4-player mid-game state so we can
        // preview the table populated with melds from every player.
        let app = XCUIApplication()
        app.launchArguments += ["--demo-mid-game"]
        app.launch()
        _ = app.navigationBars["Hand 4"].waitForExistence(timeout: 5)
        Thread.sleep(forTimeInterval: 0.7)
        snapshot(named: "04-mid-game-cozy-wood")
    }

    func testCaptureMidGameCasinoFelt() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--demo-mid-game", "--theme-felt"]
        app.launch()
        _ = app.navigationBars["Hand 4"].waitForExistence(timeout: 5)
        Thread.sleep(forTimeInterval: 0.7)
        snapshot(named: "05-mid-game-casino-felt")
    }

    func testCaptureMidGameMinimalModern() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--demo-mid-game", "--theme-minimal"]
        app.launch()
        _ = app.navigationBars["Hand 4"].waitForExistence(timeout: 5)
        Thread.sleep(forTimeInterval: 0.7)
        snapshot(named: "06-mid-game-minimal-modern")
    }

    func testCaptureStagingTray() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "--demo-mid-game", "--theme-felt", "--demo-stage-triplet"
        ]
        app.launch()
        _ = app.navigationBars["Hand 4"].waitForExistence(timeout: 5)
        Thread.sleep(forTimeInterval: 0.9)
        snapshot(named: "07-staging-tray-triplet")
    }

    // MARK: - Helpers

    private func snapshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

