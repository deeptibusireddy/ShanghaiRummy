import XCTest

/// UI tests whose only job is to walk the app and capture screenshots at each
/// key screen. CI extracts these screenshots from the .xcresult bundle and
/// uploads them as an artifact — so the developer can preview the app from
/// Windows without a Mac.
///
/// If these tests start failing after real UI changes: update the labels
/// referenced below (`app.buttons["..."]` etc.) or take the fresh screenshots
/// as the new baseline.
final class ScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
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

        // Game container appears — should show Round 1 title.
        _ = app.navigationBars["Round 1"].waitForExistence(timeout: 5)
        snapshot(named: "03-round-1-turn-start")

        // Draw from stock, then screenshot with the meld/discard phase visible.
        let stockButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Stock'")).firstMatch
        if stockButton.exists { stockButton.tap() }
        snapshot(named: "04-after-draw")

        // Tap the first card in the hand to discard it.
        // Hand cards are Text-labeled ("7♠" etc.) inside plain-style buttons.
        // Grabbing them generically as any button that's not "Stock"/"Discard"/"Quit".
        let handCards = app.buttons.allElementsBoundByIndex.filter { btn in
            let l = btn.label
            return !l.isEmpty
                && !l.hasPrefix("Stock")
                && !l.hasPrefix("Discard")
                && l != "Quit"
        }
        if let first = handCards.first {
            first.tap()
        }

        // Pass-and-play interstitial should appear.
        let passLabel = app.staticTexts["Pass the device"]
        _ = passLabel.waitForExistence(timeout: 5)
        snapshot(named: "05-pass-and-play")
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
