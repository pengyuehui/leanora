import XCTest

@MainActor final class OnboardingTests: XCTestCase {
    private func launch(_ extra: [String] = [], reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if reset { app.launchArguments.append("--reset-state") }
        app.launchArguments += extra
        app.launch()
        return app
    }

    private func finishOnboarding(_ app: XCUIApplication) {
        tap(app.buttons["onboarding.start"], in: app)
        tap(app.buttons["onboarding.next"], in: app)
        tap(app.buttons["onboarding.finish"], in: app)
        XCTAssertTrue(app.staticTexts["screen.today"].waitForExistence(timeout: 5))
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Cannot reach \(element)")
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        reveal(element, in: app)
        element.tap()
    }

    private func back(_ app: XCUIApplication) {
        let railBack = app.buttons["BackButton"]
        if railBack.exists { railBack.tap() }
        else { app.navigationBars.buttons.element(boundBy: 0).tap() }
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSkipHealthAndVisitAllTabs() {
        let app = launch()
        capture(app, name: "01-welcome")
        finishOnboarding(app)
        capture(app, name: "02-today")
        for (tab, identifier) in [("训练", "training"), ("饮食", "nutrition"), ("趋势", "trends"), ("我的", "settings")] {
            app.buttons[tab].tap()
            XCTAssertTrue(app.staticTexts["screen.\(identifier)"].exists)
            capture(app, name: "tab-\(identifier)")
        }
    }

    func testPreferenceValidationAndPersistenceAcrossRelaunch() {
        let app = launch()
        tap(app.buttons["onboarding.start"], in: app)
        let energy = app.textFields["preferences.energy"]
        energy.tap()
        energy.typeText("0")
        XCTAssertEqual(app.buttons.matching(identifier: "preferences.keyboardDone").count, 1)
        app.buttons["preferences.keyboardDone"].tap()
        tap(app.buttons["onboarding.next"], in: app)
        XCTAssertTrue(app.staticTexts["preferences.error"].exists)
        tap(app.buttons["preferences.clearEnergy"], in: app)
        energy.tap()
        energy.typeText("2200")
        app.buttons["preferences.keyboardDone"].tap()
        tap(app.buttons["onboarding.next"], in: app)
        tap(app.buttons["onboarding.finish"], in: app)
        reveal(app.staticTexts["2,200 kcal"], in: app)
        app.terminate()
        let relaunched = launch(reset: false)
        XCTAssertTrue(relaunched.staticTexts["screen.today"].exists)
        reveal(relaunched.staticTexts["2,200 kcal"], in: relaunched)
    }

    func testHealthUnavailableDoesNotBlockOnboarding() {
        let app = launch(["--health-unavailable"])
        tap(app.buttons["onboarding.start"], in: app)
        tap(app.buttons["onboarding.next"], in: app)
        tap(app.buttons["onboarding.connectHealth"], in: app)
        XCTAssertTrue(app.staticTexts["health.unavailable"].exists)
        capture(app, name: "health-unavailable")
        back(app)
        tap(app.buttons["onboarding.finish"], in: app)
        XCTAssertTrue(app.staticTexts["screen.today"].exists)
    }

    func testProcessedHealthRequestDoesNotClaimSynchronization() {
        let app = launch()
        finishOnboarding(app)
        app.buttons["我的"].tap()
        app.buttons["settings.health"].tap()
        let writing = app.switches["health.write.body"]
        writing.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(writing.value as? String, "1")
        tap(app.buttons["health.request"], in: app)
        XCTAssertTrue(app.otherElements["health.processed"].waitForExistence(timeout: 5)
                      || app.staticTexts["已完成系统访问设置"].exists)
        XCTAssertFalse(app.staticTexts["已同步"].exists)
        XCTAssertTrue(app.staticTexts["上次请求范围内可写：0 / 2 种数据类型"].exists)
        capture(app, name: "health-processed")
    }

    func testNotificationDenialDoesNotBlockNavigation() {
        let app = launch(["--notifications-denied"])
        finishOnboarding(app)
        app.buttons["我的"].tap()
        app.buttons["settings.notifications"].tap()
        app.buttons["notifications.request"].tap()
        XCTAssertTrue(app.staticTexts["notifications.denied"].waitForExistence(timeout: 5))
        capture(app, name: "notification-denied")
        back(app)
        app.buttons["训练"].tap()
        XCTAssertTrue(app.staticTexts["screen.training"].exists)
    }

    func testHealthFailureHasRetryAndBackNavigation() {
        let app = launch(["--health-failed"])
        finishOnboarding(app)
        app.buttons["我的"].tap()
        tap(app.buttons["settings.health"], in: app)
        tap(app.buttons["health.request"], in: app)
        XCTAssertTrue(app.staticTexts["health.failed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["health.request"].isEnabled)
        capture(app, name: "health-failed")
        back(app)
        XCTAssertTrue(app.staticTexts["screen.settings"].exists)
    }

    func testPrivacyCanReturnToOnboarding() {
        let app = launch()
        tap(app.buttons["onboarding.start"], in: app)
        tap(app.buttons["onboarding.next"], in: app)
        tap(app.buttons["隐私与数据说明"], in: app)
        XCTAssertTrue(app.staticTexts["privacy.title"].exists)
        back(app)
        tap(app.buttons["onboarding.finish"], in: app)
        XCTAssertTrue(app.staticTexts["screen.today"].exists)
    }

    func testLargeTypeAndDarkAppearance() {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "--dark-mode"])
        reveal(app.buttons["onboarding.start"], in: app)
        capture(app, name: "welcome-accessibility-dark")
        finishOnboarding(app)
        app.buttons["我的"].tap()
        reveal(app.buttons["settings.privacy"], in: app)
        capture(app, name: "settings-accessibility-dark")
    }

    func testSystemHealthSheetCanBeDismissedAndAppRemainsUsable() {
        let app = launch(["--system-permissions"])
        finishOnboarding(app)
        app.buttons["我的"].tap()
        app.buttons["settings.health"].tap()
        tap(app.buttons["health.request"], in: app)
        let deny = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["Don’t Allow", "不允许"])).firstMatch
        guard deny.waitForExistence(timeout: 10) else {
            XCTFail("Health system sheet did not appear: \(app.debugDescription)")
            return
        }
        capture(app, name: "system-health-sheet")
        tap(deny, in: app)
        let acknowledgement = app.alerts.buttons.matching(NSPredicate(format: "label IN %@", ["OK", "好", "确定"])).firstMatch
        if acknowledgement.waitForExistence(timeout: 3) { acknowledgement.tap() }
        XCTAssertTrue(app.staticTexts["已完成系统访问设置"].waitForExistence(timeout: 5))
        back(app)
        app.buttons["训练"].tap()
        XCTAssertTrue(app.staticTexts["screen.training"].exists)
    }

    func testSystemNotificationDenialKeepsAppUsable() {
        let app = launch(["--system-permissions"])
        finishOnboarding(app)
        app.buttons["我的"].tap()
        app.buttons["settings.notifications"].tap()
        tap(app.buttons["notifications.request"], in: app)
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = system.buttons.matching(NSPredicate(format: "label IN %@", ["Don’t Allow", "不允许"])).firstMatch
        guard deny.waitForExistence(timeout: 10) else {
            XCTFail("Notification system alert did not appear: \(system.debugDescription)")
            return
        }
        capture(app, name: "system-notification-alert")
        deny.tap()
        XCTAssertTrue(app.staticTexts["notifications.denied"].waitForExistence(timeout: 5))
        back(app)
        app.buttons["训练"].tap()
        XCTAssertTrue(app.staticTexts["screen.training"].exists)
    }
}
