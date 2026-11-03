import XCTest

@MainActor final class ReviewWorkflowTests: XCTestCase {
    private func launch(reset: Bool = true, extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--store-screenshots", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + (reset ? ["--reset-state"] : []) + extra
        app.launch()
        XCTAssertTrue(app.buttons["today.review"].waitForExistence(timeout: 60), app.debugDescription)
        return app
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        func visible() -> Bool { element.exists && element.isHittable && element.frame.maxY < app.frame.maxY - 80 && element.frame.minY > 70 }
        if element.waitForExistence(timeout: 4), visible() { return }
        for _ in 0..<16 { if visible() { return }; app.swipeUp() }
        for _ in 0..<20 { if visible() { return }; app.swipeDown() }
        XCTFail("Cannot reveal \(element)\n\(app.debugDescription)")
    }
    private func tap(_ element: XCUIElement, _ app: XCUIApplication) { reveal(element, app); element.tap() }
    private func capture(_ app: XCUIApplication, _ name: String) {
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        let value = XCTAttachment(screenshot: app.screenshot()); value.name = name; value.lifetime = .keepAlways; add(value)
    }
    private func back(_ app: XCUIApplication) {
        if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() } else { app.navigationBars.buttons.firstMatch.tap() }
    }
    private func today() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }
    func testCalendarWeekNavigationAndSelectedDayDiary() {
        let app = launch(); tap(app.buttons["today.review"], app)
        XCTAssertTrue(app.staticTexts["review.title"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["review.day.\(today())"].exists)
        capture(app, "v14-calendar-review")
        tap(app.buttons["review.previous"], app)
        tap(app.buttons["review.next"], app)
        tap(app.buttons["review.today"], app)
        tap(app.buttons["review.diary"], app)
        XCTAssertTrue(app.staticTexts["screen.nutrition"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["diet.entry.米饭（熟，长粒白米）"].exists || app.staticTexts["nutrition.energy"].exists)
        back(app)
        tap(app.buttons["review.today"], app)
        XCTAssertTrue(app.buttons["review.day.\(today())"].exists)
    }
    func testCopyDayPreviewCancelCommitAndRelaunch() {
        let app = launch(); tap(app.buttons["today.review"], app); tap(app.buttons["review.copy"], app)
        tap(app.buttons["dayCopy.confirm"], app)
        XCTAssertTrue(app.buttons["dayCopy.confirm"].label.contains("6"), app.debugDescription)
        capture(app, "v14-day-copy-preview")
        tap(app.buttons["dayCopy.cancel"], app)
        XCTAssertTrue(app.buttons["dayCopy.cancel"].waitForNonExistence(timeout: 8))
        tap(app.buttons["review.copy"], app)
        tap(app.switches["dayCopy.meal.snack"], app)
        tap(app.buttons["dayCopy.confirm"], app)
        XCTAssertTrue(app.buttons["dayCopy.confirm"].label.contains("5"), app.debugDescription)
        tap(app.buttons["dayCopy.confirm"], app)
        XCTAssertTrue(app.buttons["dayCopy.confirm"].waitForNonExistence(timeout: 12))
        app.terminate()
        let reopened = launch(reset: false)
        reopened.buttons["饮食"].tap(); tap(reopened.buttons["diet.nextDay"], reopened)
        reveal(reopened.staticTexts["nutrition.completeness"], reopened)
        XCTAssertTrue(reopened.staticTexts["nutrition.completeness"].label.contains("5"), reopened.debugDescription)
        capture(reopened, "v14-copied-day-persisted")
    }
    func testExerciseHistoryComparisonAndSourceWorkout() {
        let app = launch(); app.buttons["训练"].tap(); tap(app.buttons["training.library"], app)
        let search = app.searchFields.firstMatch; XCTAssertTrue(search.waitForExistence(timeout: 8)); search.tap(); search.typeText("杠铃卧推")
        let done = app.keyboards.buttons.matching(NSPredicate(format: "label IN %@", ["Search", "搜索"])).firstMatch
        if done.exists { done.tap() }
        tap(app.buttons["exercise.row.杠铃卧推"], app); tap(app.buttons["exercise.progress"], app)
        XCTAssertTrue(app.staticTexts["progress.latestSets"].waitForExistence(timeout: 8))
        reveal(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "正式组容量变化")).firstMatch, app)
        capture(app, "v14-exercise-progress")
        let source = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "progress.source.")).firstMatch
        tap(source, app)
        XCTAssertTrue(app.buttons["workout.close"].waitForExistence(timeout: 8))
        tap(app.buttons["workout.close"], app)
        XCTAssertTrue(app.buttons["workout.close"].waitForNonExistence(timeout: 8))
    }
    func testLargeDarkReviewAndCopyFlow() {
        let app = launch(extra: ["--dark-mode", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        tap(app.buttons["today.review"], app)
        capture(app, "v14-large-dark-calendar")
        tap(app.buttons["review.copy"], app)
        tap(app.buttons["dayCopy.confirm"], app)
        XCTAssertTrue(app.buttons["dayCopy.confirm"].label.contains("6"))
        capture(app, "v14-large-dark-copy")
        tap(app.buttons["dayCopy.cancel"], app)
        XCTAssertTrue(app.buttons["dayCopy.cancel"].waitForNonExistence(timeout: 8))
        back(app); app.buttons["饮食"].tap(); tap(app.buttons["diet.guides"], app)
        tap(app.buttons["nutrition.guide.review-copy-day"], app)
        XCTAssertTrue(app.staticTexts["选择实际吃过的餐次"].waitForExistence(timeout: 8))
        capture(app, "v14-original-review-guide")
    }
}
