import XCTest

@MainActor final class HistoryActionsTests: XCTestCase {
    private func launch(reset: Bool = true, extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--store-screenshots", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + (reset ? ["--reset-state"] : []) + extra
        app.launch(); XCTAssertTrue(app.staticTexts["screen.today"].waitForExistence(timeout: 60), app.debugDescription)
        return app
    }
    private func tap(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<24 {
            if element.exists, element.isHittable {
                let intersection = element.frame.intersection(app.frame.insetBy(dx: 0, dy: 70))
                if intersection.height >= min(40, element.frame.height), intersection.width > 0 {
                    app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: intersection.midX, dy: intersection.midY)).tap(); return
                }
            }
            if element.exists && element.frame.minY < 80 { app.swipeDown() } else { app.swipeUp() }
        }
        XCTFail("Missing element \(element)\n\(app.debugDescription)")
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let item = XCTAttachment(screenshot: app.screenshot()); item.name = name; item.lifetime = .keepAlways; add(item)
    }
    private func search(_ text: String, _ app: XCUIApplication) {
        let field = app.searchFields.firstMatch; XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(text)
        let done = app.keyboards.buttons.matching(NSPredicate(format: "label IN %@", ["Search", "搜索"])).firstMatch
        if done.exists { done.tap() }
    }
    private func back(_ app: XCUIApplication) {
        if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() } else { app.navigationBars.buttons.firstMatch.tap() }
    }
    func testMergedHistoryMonthCategoryAndStatistics() {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["历史"].exists); XCTAssertTrue(app.tabBars.buttons["动作"].exists)
        XCTAssertFalse(app.buttons["趋势"].exists)
        capture(app, "v15-history-today-calendar")
        let old = app.buttons["history.month"].value as? String
        tap(app.buttons["history.previousMonth"], app)
        XCTAssertNotEqual(app.buttons["history.month"].value as? String, old)
        tap(app.buttons["history.today"], app)
        tap(app.segmentedControls["history.category"].buttons["饮食"], app)
        tap(app.buttons["history.diary"], app)
        XCTAssertTrue(app.staticTexts["screen.nutrition"].waitForExistence(timeout: 5)); back(app)
        tap(app.segmentedControls["history.mode"].buttons["统计"], app)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "history.statistics").firstMatch.waitForExistence(timeout: 5))
        capture(app, "v15-history-statistics")
        tap(app.segmentedControls["history.category"].buttons["体重体脂"], app)
        let latest = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "最近记录")).firstMatch
        XCTAssertTrue(latest.waitForExistence(timeout: 5), app.debugDescription)
        tap(latest, app)
        capture(app, "v15-body-statistics")
    }
    func testExerciseGridMuscleEquipmentFavoriteAndTrainingRemainReachable() {
        let app = launch(); app.tabBars.buttons["动作"].tap()
        tap(app.buttons["exercise.region.胸"], app)
        capture(app, "v15-exercise-library")
        tap(app.buttons["exercise.equipment.杠铃"], app)
        search("杠铃卧推", app)
        XCTAssertTrue(app.buttons["exercise.row.杠铃卧推"].waitForExistence(timeout: 5))
        tap(app.buttons["exercise.star.杠铃卧推"], app)
        tap(app.segmentedControls["exercise.collection"].buttons["收藏"], app)
        XCTAssertTrue(app.buttons["exercise.row.杠铃卧推"].exists)
        capture(app, "v15-exercise-filter-favorite")
        tap(app.buttons["exercise.row.杠铃卧推"], app)
        XCTAssertTrue(app.buttons["exercise.guide.zoom.0"].waitForExistence(timeout: 5)); back(app)
        tap(app.buttons["exercise.training"], app)
        XCTAssertTrue(app.buttons["training.newTemplate"].waitForExistence(timeout: 5))
        tap(app.buttons["training.active"], app)
        XCTAssertTrue(app.buttons["workout.close"].waitForExistence(timeout: 5)); app.buttons["workout.close"].tap()
    }
    func testFailedAutomaticSyncRequestsAuthorizationAndStaysOff() {
        let app = launch(extra: ["--health-failed"])
        app.tabBars.buttons["我的"].tap(); tap(app.buttons["settings.health"], app)
        XCTAssertTrue(app.buttons["health.request"].isHittable)
        let automatic = app.switches["health.auto"]
        automatic.switches.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["health.failed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["health.failureCode"].exists)
        XCTAssertEqual(automatic.value as? String, "0")
        capture(app, "v15-health-authorization-error")
    }
    func testPausedHealthScopesSurviveReentryAndRelaunch() {
        var app = launch()
        app.tabBars.buttons["我的"].tap(); tap(app.buttons["settings.health"], app)
        let writing = app.switches["health.write.body"]; tap(writing.switches.firstMatch, app)
        tap(app.buttons["health.request"], app)
        XCTAssertTrue(app.staticTexts["已完成系统访问设置"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "已设置过的权限不会重复弹窗")).firstMatch.exists)
        let automatic = app.switches["health.auto"]
        tap(automatic.switches.firstMatch, app); XCTAssertEqual(automatic.value as? String, "0")
        app.terminate(); app = launch(reset: false)
        app.tabBars.buttons["我的"].tap(); tap(app.buttons["settings.health"], app)
        XCTAssertEqual(app.switches["health.write.body"].value as? String, "1")
        XCTAssertEqual(app.switches["health.auto"].value as? String, "0")
        capture(app, "v15-health-paused-scopes")
    }
    func testHistoryAndActionLargeTypeDarkLayout() {
        let app = launch(extra: ["--dark-mode", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        capture(app, "v15-history-large-dark")
        tap(app.buttons["history.nextMonth"], app)
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        tap(app.buttons["history.day.\(formatter.string(from: nextMonth))"], app)
        capture(app, "v15-calendar-large-dark")
        app.tabBars.buttons["动作"].tap(); search("鸟狗式", app)
        XCTAssertTrue(app.buttons["exercise.row.鸟狗式"].waitForExistence(timeout: 8))
        capture(app, "v15-exercises-large-dark")
        tap(app.buttons["exercise.row.鸟狗式"], app)
        XCTAssertTrue(app.buttons["exercise.guide.zoom.0"].waitForExistence(timeout: 5))
    }
}

@MainActor final class ReviewWorkflowTests: XCTestCase {
    private func launch(reset: Bool = true, extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--store-screenshots", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + (reset ? ["--reset-state"] : []) + extra
        app.launch()
        XCTAssertTrue(app.staticTexts["screen.today"].waitForExistence(timeout: 60), app.debugDescription)
        return app
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        func visible() -> Bool {
            guard element.exists, element.isHittable else { return false }
            if element.label == "历史选项" { return true }
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
    private func openWeekReview(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["history.options"].waitForExistence(timeout: 5))
        app.buttons["history.options"].tap(); app.buttons["周回顾"].tap()
    }
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
        app.tabBars.buttons["动作"].tap(); app.buttons["exercise.training"].tap(); tap(app.buttons["training.library"], app)
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
        let app = launch(); openWeekReview(app); tap(app.buttons["review.copy"], app)
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
        let app = launch(); openWeekReview(app)
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
        let app = launch(); openWeekReview(app); tap(app.buttons["review.copy"], app)
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
        reopened.tabBars.buttons["饮食"].tap(); tap(reopened.buttons["diet.nextDay"], reopened)
        reveal(reopened.staticTexts["nutrition.completeness"], reopened)
        XCTAssertTrue(reopened.staticTexts["nutrition.completeness"].label.contains("5"), reopened.debugDescription)
        capture(reopened, "v14-copied-day-persisted")
    }
    func testExerciseHistoryComparisonAndSourceWorkout() {
        let app = launch(); app.tabBars.buttons["动作"].tap(); app.buttons["exercise.training"].tap(); tap(app.buttons["training.library"], app)
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
        openWeekReview(app)
        capture(app, "v14-large-dark-calendar")
        tap(app.buttons["review.copy"], app)
        tap(app.buttons["dayCopy.confirm"], app)
        XCTAssertTrue(app.buttons["dayCopy.confirm"].label.contains("6"))
        capture(app, "v14-large-dark-copy")
        tap(app.buttons["dayCopy.cancel"], app)
        XCTAssertTrue(app.buttons["dayCopy.cancel"].waitForNonExistence(timeout: 8))
        back(app); app.tabBars.buttons["饮食"].tap(); tap(app.buttons["diet.guides"], app)
        tap(app.buttons["nutrition.guide.review-copy-day"], app)
        XCTAssertTrue(app.staticTexts["选择实际吃过的餐次"].waitForExistence(timeout: 8))
        capture(app, "v14-original-review-guide")
    }
}
