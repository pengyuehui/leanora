import XCTest

@MainActor final class NutritionWorkflowTests: XCTestCase {
    private let rice = "米饭（熟，长粒白米）"
    private func launch(reset: Bool = true, extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + (reset ? ["--reset-state"] : []) + extra
        app.launch()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.buttons["onboarding.start"].exists || app.staticTexts["screen.today"].exists }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 35), .completed)
        if app.buttons["onboarding.start"].exists {
            tap(app.buttons["onboarding.start"], app); tap(app.buttons["onboarding.next"], app); tap(app.buttons["onboarding.finish"], app)
        }
        XCTAssertTrue(app.staticTexts["screen.today"].waitForExistence(timeout: 12))
        app.buttons["饮食"].tap(); return app
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        func visible() -> Bool {
            guard element.exists, element.isHittable else { return false }
            var bottom = app.frame.maxY - 40
            let record = app.buttons["mealRecord.save"]
            if element.identifier != "mealRecord.save", record.exists && record.isHittable { bottom = min(bottom, record.frame.minY - 5) }
            return element.frame.maxY < bottom && element.frame.midY > 40
        }
        func scroll(_ up: Bool) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: up ? 0.65 : 0.35))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: up ? 0.35 : 0.65)), withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        if element.waitForExistence(timeout: 4), visible() { return }
        for _ in 0..<20 { if visible() { return }; scroll(true) }
        for _ in 0..<30 { if visible() { return }; scroll(false) }
        XCTFail("Cannot reach \(element)\n\(app.debugDescription)")
    }
    private func tap(_ element: XCUIElement, _ app: XCUIApplication) { reveal(element, app); element.tap() }
    private func search(_ name: String, _ app: XCUIApplication) {
        let field = app.searchFields.firstMatch; XCTAssertTrue(field.waitForExistence(timeout: 8), app.debugDescription); field.tap(); field.typeText(name)
        let done = app.keyboards.buttons.matching(NSPredicate(format: "label IN %@", ["Search","搜索"])).firstMatch
        if done.exists { done.tap() }
    }
    private func input(_ value: String, into field: XCUIElement, _ app: XCUIApplication) {
        reveal(field, app)
        // At AX XXXL, a labeled value may expose the entire two-line row as
        // its frame. Focus the lower value area rather than the title above it.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.8)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 4), app.debugDescription)
        field.typeText(value)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let value = XCTAttachment(screenshot: app.screenshot()); value.name = name; value.lifetime = .keepAlways; add(value)
    }
    private func back(_ app: XCUIApplication) {
        if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() } else { app.navigationBars.buttons.firstMatch.tap() }
    }
    private func waitGone(_ element: XCUIElement) { XCTAssertTrue(element.waitForNonExistence(timeout: 8)) }

    func testFoodFavoritesPreviousPortionsAndHistoryCombinationSurviveRelaunch() {
        var app = launch()
        tap(app.buttons["diet.add.breakfast"], app); search("白米饭", app); tap(app.buttons["food.select.\(rice)"], app)
        tap(app.buttons["portion.favorite"], app); XCTAssertEqual(app.buttons["portion.favorite"].label, "取消收藏")
        tap(app.buttons["portion.grams.150"], app); XCTAssertEqual(app.textFields["portion.quantity"].value as? String, "150")
        capture(app, "v13-food-portion")
        tap(app.buttons["portion.save"], app); waitGone(app.buttons["portion.save"])
        tap(app.buttons["diet.add.breakfast"], app)
        tap(app.buttons["food.filter"], app); app.buttons["收藏"].tap()
        tap(app.buttons["food.select.\(rice)"], app); tap(app.buttons["portion.previous"], app)
        XCTAssertEqual(app.textFields["portion.quantity"].value as? String, "150")
        tap(app.buttons["portion.save"], app); waitGone(app.buttons["portion.save"])
        tap(app.buttons["diet.saveMeal.breakfast"], app)
        tap(app.buttons["mealTemplate.clearName"], app); app.textFields["mealTemplate.name"].tap(); app.textFields["mealTemplate.name"].typeText("日常早餐")
        tap(app.buttons["mealTemplate.keyboardDone"], app); capture(app, "v13-meal-template-draft")
        tap(app.buttons["mealTemplate.save"], app); waitGone(app.buttons["mealTemplate.save"])
        app.terminate(); app = launch(reset: false)
        tap(app.buttons["diet.mealTemplates"], app); tap(app.buttons["mealTemplate.open.日常早餐"], app)
        tap(app.buttons["mealTemplate.record"], app); tap(app.buttons["mealRecord.servings.0.5"], app)
        capture(app, "v13-half-meal-preview")
        tap(app.buttons["mealRecord.save"], app); waitGone(app.buttons["mealRecord.save"])
        back(app); tap(app.buttons["关闭"], app)
        reveal(app.staticTexts["nutrition.energy"], app)
        XCTAssertTrue(app.staticTexts["nutrition.energy"].label.contains("585"), app.debugDescription)
        capture(app, "v13-diary-after-combination")
        app.terminate(); app = launch(reset: false)
        XCTAssertTrue(app.staticTexts["nutrition.energy"].label.contains("585"), app.debugDescription)
        app.buttons["今天"].tap(); reveal(app.staticTexts["nutrition.energy"], app)
        XCTAssertTrue(app.staticTexts["nutrition.energy"].label.contains("585"), app.debugDescription)
    }

    func testOriginalExamplesCancelThenAdoptAndOfflineGuide() {
        let app = launch()
        tap(app.buttons["diet.examples"], app); tap(app.buttons["nutrition.example.oats-yogurt-blueberries"], app)
        capture(app, "v13-original-example")
        tap(app.buttons["nutrition.example.adopt"], app); tap(app.buttons["取消"], app)
        waitGone(app.buttons["mealTemplate.save"])
        back(app); back(app); tap(app.buttons["diet.mealTemplates"], app)
        XCTAssertTrue(app.staticTexts["还没有组合餐"].waitForExistence(timeout: 5))
        tap(app.buttons["关闭"], app)
        tap(app.buttons["diet.examples"], app); tap(app.buttons["nutrition.example.oats-yogurt-blueberries"], app)
        tap(app.buttons["nutrition.example.adopt"], app); tap(app.buttons["mealTemplate.save"], app)
        waitGone(app.buttons["mealTemplate.save"])
        back(app); back(app); tap(app.buttons["diet.mealTemplates"], app)
        XCTAssertTrue(app.buttons["mealTemplate.open.燕麦、酸奶与蓝莓"].waitForExistence(timeout: 5))
        tap(app.buttons["关闭"], app); tap(app.buttons["diet.guides"], app)
        tap(app.buttons["nutrition.guide.unknowns"], app)
        XCTAssertTrue(app.staticTexts["缺少的字段留空"].waitForExistence(timeout: 5))
        capture(app, "v13-offline-nutrition-guide")
    }

    func testLargeDarkCombinationEditorAndInvalidServingsProtectDiary() {
        let app = launch(extra: ["--dark-mode", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        tap(app.buttons["diet.mealTemplates"], app); tap(app.buttons["mealTemplate.new"], app)
        tap(app.buttons["mealTemplate.addQuick"], app)
        input("100", into: app.textFields["quick.energy"], app)
        tap(app.buttons["quick.keyboardDone"], app); tap(app.buttons["quick.save"], app); waitGone(app.buttons["quick.save"])
        tap(app.buttons["mealTemplate.item."], app)
        let quantity = app.textFields["mealItem.quantity"]
        input(XCUIKeyboardKey.delete.rawValue + "2", into: quantity, app)
        XCTAssertEqual(quantity.value as? String, "2")
        tap(app.buttons["mealItem.keyboardDone"], app); tap(app.buttons["mealItem.save"], app); waitGone(app.buttons["mealItem.save"])
        tap(app.buttons["mealTemplate.save"], app); waitGone(app.buttons["mealTemplate.save"])
        tap(app.buttons["mealTemplate.open.我的组合"], app); tap(app.buttons["mealTemplate.record"], app)
        let servings = app.textFields["mealRecord.servings"]; input(XCUIKeyboardKey.delete.rawValue + "0", into: servings, app)
        XCTAssertEqual(servings.value as? String, "0")
        tap(app.buttons["mealRecord.save"], app)
        reveal(app.staticTexts["mealRecord.error"], app)
        capture(app, "v13-large-dark-invalid-meal")
        tap(app.buttons["mealRecord.servings.0.5"], app); tap(app.buttons["mealRecord.save"], app); waitGone(app.buttons["mealRecord.save"])
        back(app); tap(app.buttons["关闭"], app)
        reveal(app.staticTexts["nutrition.energy"], app)
        XCTAssertTrue(app.staticTexts["nutrition.energy"].label.contains("100"), app.debugDescription)
        reveal(app.staticTexts["nutrition.completeness"], app)
        XCTAssertTrue(app.staticTexts["nutrition.completeness"].label.contains("未知"))
        capture(app, "v13-large-dark-diary")
    }
}
