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
        XCTAssertFalse(app.buttons["Hot-Seat (Pass & Play)"].exists)
        XCTAssertFalse(app.buttons["Quick Pair (2-Player Beta Test)"].exists)
        createTable.tap()

        XCTAssertTrue(
            app.navigationBars["Create Table"].waitForExistence(timeout: 5)
        )
        snapshot(named: "02-create-table-setup")

        app.buttons["add-family-bot"].tap()
        let start = app.buttons["start-family-table"]
        XCTAssertTrue(start.waitForExistence(timeout: 2))
        XCTAssertTrue(start.isEnabled)
        start.tap()

        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your Draw"].waitForExistence(timeout: 5))
        // Small pause so the scene finishes its first frame.
        Thread.sleep(forTimeInterval: 0.5)
        snapshot(named: "03-hand-1-scaffold")
    }

    func testCaptureFamilyTableSetup() throws {
        app.launchArguments += ["--demo-family-table-setup"]
        app.launch()

        XCTAssertTrue(
            app.navigationBars["Create Table"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["You"].exists)
        XCTAssertFalse(app.staticTexts["Bot 1"].exists)
        let start = app.buttons["start-family-table"]
        XCTAssertTrue(start.exists)
        XCTAssertFalse(start.isEnabled)
        snapshot(named: "02-family-table-setup")

        let addBot = app.buttons["add-family-bot"]
        XCTAssertTrue(addBot.exists)
        addBot.tap()
        XCTAssertTrue(app.staticTexts["Bot 1"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Remove Bot 1"].exists)
        XCTAssertTrue(start.isEnabled)
        start.tap()
        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
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
        app.launchArguments += ["--demo-mid-game", "--demo-stage-triplet"]
        app.launch()
        XCTAssertTrue(app.buttons["quit-game"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.9)
        snapshot(named: "07-staging-tray-triplet")
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
