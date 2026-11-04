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
        func visible() -> Bool {
            guard element.exists, element.isHittable else { return false }
            if ["workout.close", "dayCopy.cancel"].contains(element.identifier) { return true }
            var bottom = app.frame.maxY - 40
            let confirm = app.buttons["dayCopy.confirm"]
            if element.identifier == "dayCopy.confirm" { bottom = app.frame.maxY - 5 }
            else if confirm.exists && confirm.isHittable { bottom = min(bottom, confirm.frame.minY - 5) }
            // Accessibility-sized rows may be taller than the viewport. A
            // hittable 44pt intersection is sufficient to activate a link.
            return min(element.frame.maxY, bottom) - max(element.frame.minY, 70) >= min(44, element.frame.height)
        }
        func scroll(up: Bool) {
            let confirm = app.buttons["dayCopy.confirm"]
            let bottom = confirm.exists && confirm.isHittable ? min(0.76, (confirm.frame.minY - 20) / app.frame.height) : 0.76
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: up ? bottom : 0.22))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: up ? 0.22 : bottom)), withVelocity: .fast, thenHoldForDuration: 0.1)
        }
        if element.waitForExistence(timeout: 4), visible() { return }
        let header = element.exists && ["review.previous", "review.next", "review.today"].contains(element.identifier)
        for _ in 0..<50 { if visible() { return }; scroll(up: !header) }
        for _ in 0..<35 { if visible() { return }; scroll(up: header) }
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
    func testCardioHistoryKeepsMissingDistanceUnknown() {
        let app = launch(extra: ["--review-cardio-samples"])
        app.buttons["训练"].tap(); tap(app.buttons["training.library"], app)
        let search = app.searchFields.firstMatch; XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.tap(); search.typeText("有氧记录验证")
        let done = app.keyboards.buttons.matching(NSPredicate(format: "label IN %@", ["Search", "搜索"])).firstMatch
        if done.exists { done.tap() }
        tap(app.buttons["exercise.row.有氧记录验证"], app); tap(app.buttons["exercise.progress"], app)
        let distance = app.descendants(matching: .any).matching(identifier: "progress.distance").firstMatch
        reveal(distance, app)
        XCTAssertTrue(distance.label.contains("未记录"), app.debugDescription)
        reveal(app.staticTexts["距离记录不完整，暂不比较差值"], app)
        capture(app, "v14-cardio-unknown-distance")
    }
    func testCaptureCopyDayPreviewForStore() {
        let app = launch(); tap(app.buttons["today.review"], app); tap(app.buttons["review.copy"], app)
        tap(app.buttons["dayCopy.confirm"], app)
        XCTAssertTrue(app.buttons["dayCopy.confirm"].label.contains("6"))
        reveal(app.staticTexts["复制预览 · 6 项"], app)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.60))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.25)), withVelocity: .slow, thenHoldForDuration: 0.1)
        capture(app, "v14-day-copy-details")
        tap(app.buttons["dayCopy.cancel"], app)
        XCTAssertTrue(app.buttons["dayCopy.cancel"].waitForNonExistence(timeout: 8))
    }
    func testCalendarWeekNavigationAndSelectedDayDiary() {
        let app = launch(); tap(app.buttons["today.review"], app)
        XCTAssertTrue(app.staticTexts["review.title"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["review.day.\(today())"].exists)
        capture(app, "v14-calendar-review")
        tap(app.buttons["review.previous"], app)
        reveal(app.staticTexts["这一天没有已结束训练"], app)
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
        let snack = app.switches["dayCopy.meal.snack"]
        reveal(snack, app)
        snack.switches.firstMatch.tap()
        XCTAssertEqual(snack.value as? String, "0")
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
