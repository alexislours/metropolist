import XCTest

@MainActor
final class ScreenshotTests: XCTestCase, @unchecked Sendable {
    var app: XCUIApplication!

    nonisolated override func setUpWithError() throws {
        MainActor.assumeIsolated {
            continueAfterFailure = false
            app = XCUIApplication()
            setupSnapshot(app)
        }
    }

    // MARK: - Per-Language Test Entry Points

    func testScreenshots_EnUS() { runScreenshots(language: "en-US", locale: "en_US") }
    func testScreenshots_FrFR() { runScreenshots(language: "fr-FR", locale: "fr_FR") }

    // MARK: - Shared Runner

    private func runScreenshots(language: String, locale: String) {
        MainActor.assumeIsolated {
            Snapshot.deviceLanguage = language
            Snapshot.currentLocale = locale
        }

        app.launchArguments = [
            "--screenshots",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
            "-FASTLANE_SNAPSHOT", "YES",
            "-ui_testing",
        ]

        XCUIDevice.shared.appearance = .light
        app.launch()

        // Wait for Lines tab content to load
        let collectionView = app.collectionViews.firstMatch
        XCTAssertTrue(collectionView.waitForExistence(timeout: 10))
        sleep(2)

        // ── 01  Lines Tab ──
        snapshot("01-Lines")

        // ── 02  Line Detail ──
        captureLineDetail()

        // ── 03 & 04  Travel Confirm & Success ──
        captureTravelFlow()

        // ── 05  Profile ──
        app.tabBars.buttons.element(boundBy: 1).tap()
        sleep(2)
        snapshot("05-Profile")

        // ── 06  Badges ──
        let badgesTile = app.buttons["tile-badges"].firstMatch
        XCTAssertTrue(badgesTile.waitForExistence(timeout: 5))
        badgesTile.tap()
        sleep(1)
        snapshot("06-Badges")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        // ── 07  Achievements ──
        let achievementsTile = app.buttons["tile-achievements"].firstMatch
        XCTAssertTrue(achievementsTile.waitForExistence(timeout: 5))
        achievementsTile.tap()
        sleep(1)
        snapshot("07-Achievements")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        // ── 08  Stats ──
        let statsLink = app.buttons["link-statistics"].firstMatch
        XCTAssertTrue(statsLink.waitForExistence(timeout: 5))
        statsLink.tap()
        sleep(1)
        snapshot("08-Stats")
    }

    // MARK: - 02 Line Detail

    private func captureLineDetail() {
        // Metro 14 is first in "In Progress" (85% complete, section expanded by default)
        let metro14 = app.buttons["line-14"].firstMatch
        XCTAssertTrue(metro14.waitForExistence(timeout: 5))
        metro14.tap()
        sleep(3) // map + content load
        snapshot("02-LineDetail")

        // Go back to Lines tab
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)
    }

    // MARK: - 03 & 04 Travel Flow

    private func captureTravelFlow() {
        // Navigate to Metro 14 detail again
        let metro14 = app.buttons["line-14"].firstMatch
        XCTAssertTrue(metro14.waitForExistence(timeout: 5))
        metro14.tap()
        sleep(2)

        // Tap "Start travel" — opens travel flow sheet with Metro 14 prefilled
        let startTravel = app.buttons["button-start-travel"].firstMatch
        XCTAssertTrue(startTravel.waitForExistence(timeout: 5))
        startTravel.tap()
        sleep(2)

        // Station picker shows Metro 14 stops — pick first station as origin
        let originCell = app.cells.element(boundBy: 0)
        XCTAssertTrue(originCell.waitForExistence(timeout: 5))
        originCell.tap()
        sleep(2) // destinations load async

        // Destination picker — pick a station further away for a nice timeline
        let destCell = app.cells.element(boundBy: 6)
        XCTAssertTrue(destCell.waitForExistence(timeout: 10))
        destCell.tap()
        sleep(1)

        // Handle possible variant picker (if multiple branches)
        let confirmButton = app.buttons["button-confirm-travel"].firstMatch
        if !confirmButton.waitForExistence(timeout: 2) {
            // Variant picker appeared — pick first option
            let variantCell = app.cells.element(boundBy: 6)
            if variantCell.waitForExistence(timeout: 3) {
                variantCell.tap()
                sleep(1)
            }
        }

        // ── 03  Travel Confirm ──
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        snapshot("03-TravelConfirm")

        // ── 04  Travel Success ──
        confirmButton.tap()
        sleep(3) // wait for success animations to finish
        snapshot("04-TravelSuccess")

        // Dismiss travel flow
        let doneButton = app.buttons["button-done"].firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()
        sleep(1)

        // Back to Lines tab from line detail
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)
    }
}
