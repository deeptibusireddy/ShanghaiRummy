import XCTest

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

        // Home → New Game setup
        let hotSeat = app.buttons["Hot-Seat (Pass & Play)"]
        XCTAssertTrue(hotSeat.waitForExistence(timeout: 5), "Home menu should show hot-seat button")
        hotSeat.tap()

        // Setup sheet appears
        _ = app.navigationBars["New Game"].waitForExistence(timeout: 5)
        snapshot(named: "02-new-game-setup")

        // Start the game with the default 2 players.
        app.buttons["Start"].tap()

        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
        // Small pause so the scene finishes its first frame.
        Thread.sleep(forTimeInterval: 0.5)
        snapshot(named: "03-hand-1-scaffold")
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
        app.launchArguments += ["--demo-mid-game", "--demo-stage-triplet"]
        app.launch()
        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.9)
        snapshot(named: "07-staging-tray-triplet")
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
        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.9)
        snapshot(named: "09-game-over-final")
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
