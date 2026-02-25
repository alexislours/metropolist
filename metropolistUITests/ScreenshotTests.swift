import XCTest

@MainActor
final class ScreenshotTests: XCTestCase, @unchecked Sendable {
    var app: XCUIApplication!

    nonisolated override func setUpWithError() throws {
        MainActor.assumeIsolated {
            continueAfterFailure = false
            app = XCUIApplication()
            setupSnapshot(app, waitForAnimations: false)
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
            "-hasSeenOnboarding", "YES",
        ]

        XCUIDevice.shared.appearance = .light
        app.launch()

        // Wait for Lines tab content to fully render (specific line button = list populated)
        let metro14 = app.buttons["line-14"].firstMatch
        XCTAssertTrue(metro14.waitForExistence(timeout: 10))

        // ── 01  Lines Tab ──
        snap("01-Lines")

        // ── 02  Line Detail ──
        captureLineDetail(metro14: metro14)

        // ── 03 & 04  Travel Confirm & Success ──
        captureTravelFlow()

        // ── 05  Profile ──
        let profilePredicate = NSPredicate(format: "label CONTAINS[c] 'profil'")
        let profileTab = app.tabBars.buttons.matching(profilePredicate).firstMatch
        if !profileTab.waitForExistence(timeout: 3) {
            // Fallback — find by label across all buttons (iPad sidebar, etc.)
            let profileButton = app.buttons.matching(profilePredicate).firstMatch
            XCTAssertTrue(profileButton.waitForExistence(timeout: 5))
            profileButton.tap()
        } else {
            profileTab.tap()
        }
        let badgesTile = app.buttons["tile-badges"].firstMatch
        XCTAssertTrue(badgesTile.waitForExistence(timeout: 10))
        snap("05-Profile")

        // ── 06  Badges ──
        badgesTile.tap()
        let badgesView = app.scrollViews["view-badges-detail"].firstMatch
        XCTAssertTrue(badgesView.waitForExistence(timeout: 5))
        snap("06-Badges")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(badgesTile.waitForExistence(timeout: 5))

        // ── 07  Achievements ──
        let achievementsTile = app.buttons["tile-achievements"].firstMatch
        achievementsTile.tap()
        let achievementsView = app.scrollViews["view-achievements-detail"].firstMatch
        XCTAssertTrue(achievementsView.waitForExistence(timeout: 5))
        snap("07-Achievements")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(achievementsTile.waitForExistence(timeout: 5))

        // ── 08  Stats ──
        let statsLink = app.buttons["link-statistics"].firstMatch
        statsLink.tap()
        let statsView = app.scrollViews["view-stats-detail"].firstMatch
        XCTAssertTrue(statsView.waitForExistence(timeout: 5))
        snap("08-Stats")
    }

    // MARK: - 02 Line Detail

    private func captureLineDetail(metro14: XCUIElement) {
        metro14.tap()
        let startTravel = app.buttons["button-start-travel"].firstMatch
        XCTAssertTrue(startTravel.waitForExistence(timeout: 10))
        snap("02-LineDetail")
    }

    // MARK: - 03 & 04 Travel Flow

    private func captureTravelFlow() {
        let startTravel = app.buttons["button-start-travel"].firstMatch
        startTravel.tap()

        // Station picker — pick first station as origin
        let originCell = app.cells.element(boundBy: 0)
        XCTAssertTrue(originCell.waitForExistence(timeout: 5))
        originCell.tap()

        // Destination picker — pick a station further away
        let destCell = app.cells.element(boundBy: 6)
        XCTAssertTrue(destCell.waitForExistence(timeout: 10))
        destCell.tap()


        let variantCell = app.cells.element(boundBy: 6)
        if variantCell.waitForExistence(timeout: 1) {
            variantCell.tap()
        }

        // Handle possible variant picker (if multiple branches)
        let confirmButton = app.buttons["button-confirm-travel"].firstMatch

        // ── 03  Travel Confirm ──
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        snap("03-TravelConfirm")

        // ── 04  Travel Success ──
        confirmButton.tap()
        let doneButton = app.buttons["button-done"].firstMatch
        waitForHittable(doneButton, timeout: 5)
        sleep(6)
        snap("04-TravelSuccess")

        // Dismiss travel flow — wait for sheet to fully dismiss before navigating
        doneButton.tap()
        waitForHittable(app.buttons["button-start-travel"].firstMatch, timeout: 5)
    }

    // MARK: - Helpers

    /// Takes a snapshot with no idle wait (we already ensure readiness via wait conditions).
    private func snap(_ name: String) {
        snapshot(name, timeWaitingForIdle: 0)
    }

    /// Waits for an element to become hittable (visible and interactable).
    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 5) {
        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Element did not become hittable within \(timeout)s")
    }
}
