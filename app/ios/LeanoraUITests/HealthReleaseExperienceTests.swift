import XCTest

@MainActor final class HealthReleaseExperienceTests: XCTestCase {
    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--reset-state", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + extra
        app.launch()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.buttons["onboarding.start"].exists || app.staticTexts["screen.today"].exists }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
        if app.buttons["onboarding.start"].exists {
            tap(app.buttons["onboarding.start"], app); tap(app.buttons["onboarding.next"], app); tap(app.buttons["onboarding.finish"], app)
        }
        XCTAssertTrue(app.staticTexts["screen.today"].waitForExistence(timeout: 8)); return app
    }
    private func tap(_ element: XCUIElement, _ app: XCUIApplication) {
        for attempt in 0..<22 {
            if element.exists && element.isHittable && element.isEnabled && element.frame.maxY <= app.frame.maxY - 35 {
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); return
            }
            if let surface = app.collectionViews.allElementsBoundByIndex.last, surface.exists {
                if (element.exists && element.frame.maxY < surface.frame.minY + 120) || (!element.exists && (3..<13).contains(attempt)) { surface.swipeDown() } else { surface.swipeUp() }
            } else { app.swipeUp() }
        }; XCTFail(app.debugDescription)
    }
    private func capture(_ app: XCUIApplication, _ name: String) { let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a) }
    private func back(_ app: XCUIApplication) {
        if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() }
        else { app.navigationBars.buttons.firstMatch.tap() }
    }
    private func addQuick(_ value: String, _ app: XCUIApplication) {
        tap(app.buttons["diet.addMenu"], app)
        tap(app.buttons["diet.menuQuick"], app)
        XCTAssertTrue(app.textFields["quick.energy"].waitForExistence(timeout: 8), app.debugDescription)
        app.textFields["quick.energy"].tap(); app.textFields["quick.energy"].typeText(value)
        app.buttons["quick.keyboardDone"].tap(); app.buttons["quick.save"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["quick.save"])], timeout: 8), .completed)
    }

    func testHealthStatusAndCacheCleanupKeepLocalRecordingAvailable() {
        let app = launch(); app.buttons["我的"].tap(); tap(app.buttons["settings.health"], app)
        tap(app.buttons["health.status"], app)
        XCTAssertTrue(app.staticTexts["读取：按系统允许的可读范围"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["暂未读到数据，可检查健康访问或手动记录。"].exists)
        XCTAssertFalse(app.buttons["health.retry"].isEnabled)
        capture(app, "u678-health-status-empty")
        back(app); back(app); tap(app.buttons["settings.data"], app)
        tap(app.buttons["data.clearCache"], app); app.buttons["确认清理"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["backup.notice"].waitForExistence(timeout: 5)); capture(app, "u678-separated-data-controls")
        app.buttons["饮食"].tap(); addQuick("123", app)
        XCTAssertTrue(app.staticTexts["nutrition.energy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["nutrition.energy"].label.contains("123"))
    }

    func testCSVSavePanelAndTypedLocalReset() {
        let app = launch(); app.buttons["饮食"].tap(); addQuick("100", app)
        app.buttons["我的"].tap(); tap(app.buttons["settings.data"], app)
        tap(app.buttons["backup.csv"], app)
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "取消"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5)); capture(app, "u678-csv-native-export"); cancel.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: cancel)], timeout: 8), .completed)
        app.collectionViews.firstMatch.swipeDown()
        tap(app.buttons["data.reset"], app)
        XCTAssertFalse(app.buttons["data.confirmReset"].isEnabled)
        app.textFields["data.resetText"].tap(); app.textFields["data.resetText"].typeText("清除")
        app.buttons["data.keyboardDone"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        capture(app, "u678-reset-explicit-confirmation")
        tap(app.buttons["data.confirmReset"], app)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.textFields["data.resetText"])], timeout: 8), .completed)
        app.buttons["饮食"].tap()
        XCTAssertTrue(app.staticTexts["尚无记录，不代表零摄入。"].waitForExistence(timeout: 5))
        capture(app, "u678-after-local-reset")
    }

    func testTodayAndHealthLargeTypeDarkLayout() throws {
        let app = launch(extra: ["--dark-mode", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.buttons["today.training"].exists); capture(app, "u678-today-large-dark")
        app.buttons["我的"].tap(); tap(app.buttons["settings.health"], app); tap(app.buttons["health.status"], app)
        capture(app, "u678-health-large-dark")
        try app.performAccessibilityAudit(for: [.contrast, .textClipped])
    }

    func testSystemHealthAllowedWriteAndEcho() {
        let app = launch(extra: ["--system-permissions"])
        app.buttons["我的"].tap(); tap(app.buttons["settings.health"], app)
        let writing = app.switches["health.write.body"]
        writing.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        tap(app.buttons["health.request"], app)
        let selectAll = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ OR label CONTAINS %@", "Select All", "全部")).firstMatch
        if selectAll.waitForExistence(timeout: 3) {
            capture(app, "u678-system-health-selection")
            tap(selectAll, app)
            // Health's consent UI is a UITableView, separate from the underlying
            // SwiftUI form. Its offscreen child frames are placeholders on Duo.
            for _ in 0..<4 { app.tables.firstMatch.swipeUp() }
            capture(app, "u678-system-health-before-allow")
            let allow = app.buttons["UIA.Health.Allow.Button"]
            guard allow.waitForExistence(timeout: 5) else { XCTFail(app.debugDescription); return }
            // The system consent action is pinned at the bottom; the ordinary
            // scroll helper deliberately excludes that edge for scrolling lists.
            allow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let limitedHistory = app.staticTexts["Past 30 Days and Future Data"]
            if limitedHistory.waitForExistence(timeout: 3) {
                limitedHistory.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                let finalAllow = app.buttons.matching(NSPredicate(format: "label IN %@", ["Allow", "允许"])).firstMatch
                guard finalAllow.waitForExistence(timeout: 3), finalAllow.isEnabled else { XCTFail(app.debugDescription); return }
                capture(app, "u678-system-health-limited-history")
                finalAllow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            // Current Health consent labels this action Continue after selecting
            // scopes; a subsequent system page may require a final confirmation.
            for _ in 0..<3 {
                if app.staticTexts["已完成系统访问设置"].waitForExistence(timeout: 1) { break }
                if allow.exists { allow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
            }
        }
        let acknowledgement = app.alerts.buttons.matching(NSPredicate(format: "label IN %@", ["OK", "好", "确定"])).firstMatch
        if acknowledgement.waitForExistence(timeout: 2) { acknowledgement.tap() }
        guard app.staticTexts["已完成系统访问设置"].waitForExistence(timeout: 10) else { XCTFail(app.debugDescription); return }
        back(app); app.buttons["今天"].tap(); tap(app.buttons["today.body"], app); tap(app.buttons["body.add"], app)
        app.textFields["body.value"].tap(); app.textFields["body.value"].typeText("65.4")
        app.buttons["body.keyboardDone"].tap(); app.buttons["body.save"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["body.save"])], timeout: 8), .completed)
        app.buttons["我的"].tap(); tap(app.buttons["settings.health"], app); tap(app.buttons["health.status"], app)
        let link = app.descendants(matching: .any).matching(identifier: "health.linked").firstMatch
        let confirmed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in link.exists && link.label.contains("1") }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [confirmed], timeout: 20), .completed, app.debugDescription)
        tap(app.buttons["health.retry"], app)
        XCTAssertTrue(link.label.contains("1")); capture(app, "u678-system-health-write-echo")
    }
}
