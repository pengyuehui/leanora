import XCTest

@MainActor final class NutritionBodyTests: XCTestCase {
    private func launch(reset: Bool = true, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + extra
        if reset { app.launchArguments.append("--reset-state") }; app.launch()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.buttons["onboarding.start"].exists || app.staticTexts["screen.today"].exists }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
        if app.buttons["onboarding.start"].exists {
            tap(app.buttons["onboarding.start"], app); tap(app.buttons["onboarding.next"], app); tap(app.buttons["onboarding.finish"], app)
        }
        XCTAssertTrue(app.staticTexts["screen.today"].waitForExistence(timeout: 8)); return app
    }
    private func tap(_ element: XCUIElement, _ app: XCUIApplication) {
        func visible() -> Bool { element.exists && element.isHittable && element.isEnabled && element.frame.maxY < app.frame.maxY - 40 && element.frame.midY > 30 }
        func scroll(_ up: Bool) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: up ? 0.65 : 0.35))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: up ? 0.35 : 0.65)), withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        if element.waitForExistence(timeout: 4), visible() { element.tap(); return }
        for _ in 0..<18 { if visible() { element.tap(); return }; scroll(true) }
        for _ in 0..<25 { if visible() { element.tap(); return }; scroll(false) }
        XCTFail(app.debugDescription)
    }
    private func capture(_ app: XCUIApplication, _ name: String) { let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a) }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for attempt in 0..<22 {
            if element.exists && element.isHittable { return }
            if let surface = app.collectionViews.allElementsBoundByIndex.last {
                if (element.exists && element.frame.maxY < surface.frame.minY + 120) || (!element.exists && (3..<13).contains(attempt)) { surface.swipeDown() } else { surface.swipeUp() }
            } else { app.swipeUp() }
        }; XCTFail(app.debugDescription)
    }
    private func search(_ term: String, _ app: XCUIApplication) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8), app.debugDescription)
        field.tap(); field.typeText(term)
        let submit = app.keyboards.buttons.matching(NSPredicate(format: "label IN %@", ["Search", "搜索"])).firstMatch; if submit.exists { submit.tap() }
    }
    private func waitGone(_ element: XCUIElement) { XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)], timeout: 5), .completed) }
    func testFoodPortionQuickCaloriesCopyAndPersistence() {
        var app = launch(); app.buttons["饮食"].tap(); tap(app.buttons["diet.add.breakfast"], app)
        search("米饭", app); tap(app.buttons["food.select.米饭（熟，长粒白米）"], app)
        XCTAssertTrue(app.staticTexts["food.source"].label.contains("USDA"))
        tap(app.buttons["portion.clear"], app); app.textFields["portion.quantity"].tap(); app.textFields["portion.quantity"].typeText("150")
        app.buttons["portion.keyboardDone"].tap(); capture(app, "u5-food-source-portion")
        tap(app.buttons["portion.save"], app); waitGone(app.buttons["portion.save"])
        // A sheet dismissal can leave the Duo runtime's accessibility scroll
        // offsets stale. A real scroll reconciles geometry before the next tap.
        app.collectionViews.firstMatch.swipeDown()
        capture(app, "u5-diary-after-food-save")
        tap(app.buttons["diet.quick"], app); XCTAssertTrue(app.textFields["quick.energy"].waitForExistence(timeout: 8)); app.textFields["quick.energy"].tap(); app.textFields["quick.energy"].typeText("100")
        app.buttons["quick.keyboardDone"].tap(); app.buttons["quick.save"].tap(); waitGone(app.buttons["quick.save"])
        app.collectionViews.firstMatch.swipeDown()
        tap(app.buttons["diet.copy"], app); tap(app.buttons["diet.copyToday"], app); app.buttons["diet.confirmCopy"].tap(); waitGone(app.buttons["diet.confirmCopy"])
        capture(app, "u5-diary-copied-meal")
        app.terminate(); app = launch(reset: false); app.buttons["饮食"].tap()
        XCTAssertTrue(app.staticTexts["nutrition.energy"].label.contains("490"), app.debugDescription)
        capture(app, "u5-diary-recovered")
        app.buttons["今天"].tap(); tap(app.staticTexts["nutrition.energy"], app)
        XCTAssertTrue(app.staticTexts["nutrition.energy"].label.contains("490"), app.debugDescription)
        capture(app, "u5-today-summary")
    }
    func testCustomFoodAndTwoBodyMeasurements() {
        let app = launch(); app.buttons["饮食"].tap(); tap(app.buttons["diet.add.breakfast"], app); tap(app.buttons["food.custom"], app)
        app.textFields["food.name"].tap(); app.textFields["food.name"].typeText("我的酸奶")
        app.buttons["food.keyboardDone"].tap()
        tap(app.textFields["food.energy"], app); app.textFields["food.energy"].typeText("80")
        app.buttons["food.keyboardDone"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        tap(app.buttons["food.save"], app); waitGone(app.buttons["food.save"])
        search("我的酸奶", app); tap(app.buttons["food.select.我的酸奶"], app)
        tap(app.buttons["portion.save"], app); waitGone(app.buttons["portion.save"])
        app.buttons["趋势"].tap(); tap(app.buttons["trends.body"], app)
        for value in ["65", "65.2"] {
            tap(app.buttons["body.add"], app); app.textFields["body.value"].tap(); app.textFields["body.value"].typeText(value)
            app.buttons["body.keyboardDone"].tap(); app.buttons["body.save"].tap(); waitGone(app.buttons["body.save"])
        }
        XCTAssertEqual(app.buttons.matching(identifier: "body.record").count, 2); capture(app, "u5-multiple-body-records")
        if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() } else { app.navigationBars.buttons.firstMatch.tap() }
        app.swipeUp(); app.swipeUp(); capture(app, "u5-body-nutrition-trends")
    }
    func testInvalidQuickAndZeroPortionCannotSaveInDarkLargeText() {
        let app = launch(extra: ["--dark-mode", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        app.buttons["饮食"].tap(); tap(app.buttons["diet.quick"], app); app.buttons["quick.save"].tap()
        reveal(app.staticTexts["quick.error"], app); capture(app, "u5-quick-validation-large-dark")
        tap(app.buttons["取消"], app); tap(app.buttons["diet.add.breakfast"], app)
        search("米饭", app); tap(app.buttons["food.select.米饭（熟，长粒白米）"], app)
        tap(app.buttons["portion.clear"], app); app.textFields["portion.quantity"].tap(); app.textFields["portion.quantity"].typeText("0")
        app.buttons["portion.keyboardDone"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); tap(app.buttons["portion.save"], app)
        reveal(app.staticTexts["portion.error"], app); capture(app, "u5-zero-portion-validation")
    }
}
