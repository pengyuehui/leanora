import XCTest

@MainActor final class TrainingWorkflowTests: XCTestCase {
    private func launch(reset: Bool = true, extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + (reset ? ["--reset-state"] : []) + extra
        app.launch()
        if app.buttons["onboarding.start"].waitForExistence(timeout: reset ? 20 : 3) {
            tap(app.buttons["onboarding.start"], app); tap(app.buttons["onboarding.next"], app); tap(app.buttons["onboarding.finish"], app)
        }
        XCTAssertTrue(app.staticTexts["screen.today"].waitForExistence(timeout: 12))
        app.buttons["训练"].tap()
        return app
    }
    @discardableResult private func reveal(_ element: XCUIElement, _ app: XCUIApplication) -> Bool {
        func reachable() -> Bool {
            guard element.exists, element.isHittable else { return false }
            var bottom = app.frame.maxY - 40
            let finish = app.buttons["workout.finish"]
            if element.identifier.hasPrefix("workout."), !element.identifier.hasPrefix("workout.confirm"), !["workout.finish", "workout.restSkip"].contains(element.identifier), finish.exists && finish.isHittable {
                bottom = min(bottom, finish.frame.minY - 8)
            }
            return element.frame.maxY < bottom && element.frame.midY > 20
        }
        func scroll(up: Bool) {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: up ? 0.65 : 0.35))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: up ? 0.35 : 0.65))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        if element.waitForExistence(timeout: 3), reachable() { return true }
        for _ in 0..<18 { if reachable() { return true }; scroll(up: true) }
        for _ in 0..<30 { if reachable() { return true }; scroll(up: false) }
        XCTFail("Cannot reach \(element)\n\(app.debugDescription)")
        return false
    }
    private func tap(_ element: XCUIElement, _ app: XCUIApplication) {
        if reveal(element, app) { element.tap() }
    }
    private func search(_ name: String, _ app: XCUIApplication) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(name)
        let search = app.keyboards.buttons.matching(NSPredicate(format: "label IN %@", ["Search", "搜索"])).firstMatch
        if search.exists { search.tap() }
    }
    private func add(_ name: String, _ app: XCUIApplication) {
        tap(app.buttons["workout.addExercise"], app); search(name, app)
        tap(app.buttons["exercise.select.\(name)"], app)
        XCTAssertTrue(reveal(app.buttons["workout.set.0.0"], app))
    }
    private func editReps(_ reps: String, set: Int, _ app: XCUIApplication) {
        tap(app.buttons["workout.set.0.\(set)"], app)
        tap(app.buttons["set.clear.reps"], app)
        app.textFields["set.reps"].tap(); app.textFields["set.reps"].typeText(reps)
        tap(app.buttons["set.keyboardDone"], app); tap(app.buttons["set.save"], app)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
    private func back(_ app: XCUIApplication) {
        if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() }
        else { app.navigationBars.buttons.firstMatch.tap() }
    }

    func testFreeWorkoutFinishTemplateRepeatAndPreviousValuesSurviveRelaunch() {
        var app = launch(); capture(app, "v12-training-home")
        tap(app.buttons["training.freeStart"], app)
        XCTAssertTrue(app.staticTexts["workout.empty"].waitForExistence(timeout: 5))
        add("俯卧撑", app); editReps("8", set: 0, app)
        tap(app.buttons["workout.complete.0.0"], app)
        tap(app.buttons["workout.finish"], app)
        let confirm = app.buttons["workout.confirmFinish"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 4)); confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["workout.close"].waitForNonExistence(timeout: 6))
        tap(app.buttons["training.history"], app); tap(app.buttons["history.自由训练"], app)
        XCTAssertEqual(app.staticTexts["workout.status"].label, "训练已完成")
        tap(app.buttons["workout.saveTemplate"], app)
        XCTAssertTrue(app.textFields["template.name"].waitForExistence(timeout: 5))
        tap(app.buttons["template.clearName"], app)
        app.textFields["template.name"].tap(); app.textFields["template.name"].typeText("徒手记录模板")
        tap(app.buttons["template.keyboardDone"], app); tap(app.buttons["template.save"], app)
        tap(app.buttons["workout.close"], app)
        tap(app.buttons["history.repeat.自由训练"], app)
        XCTAssertTrue(reveal(app.staticTexts["workout.previous.0"], app))
        XCTAssertTrue(reveal(app.buttons["workout.set.0.0"], app))
        XCTAssertTrue(app.buttons["workout.set.0.0"].label.contains("8"))
        tap(app.buttons["workout.addSet.0"], app)
        editReps("10", set: 0, app); tap(app.buttons["workout.complete.0.0"], app)
        editReps("15", set: 1, app); tap(app.buttons["workout.reusePrevious.0"], app)
        XCTAssertTrue(app.buttons["workout.set.0.0"].label.contains("10"))
        XCTAssertTrue(app.buttons["workout.set.0.0"].label.contains("已完成"))
        XCTAssertTrue(app.buttons["workout.set.0.1"].label.contains("8"))
        capture(app, "v12-previous-performance")
        app.terminate(); app = launch(reset: false)
        tap(app.buttons["training.active"], app)
        XCTAssertTrue(reveal(app.buttons["workout.set.0.0"], app))
        XCTAssertTrue(app.buttons["workout.set.0.0"].label.contains("10"))
        capture(app, "v12-workout-recovered")
    }

    func testFavoriteProgramPreviewAdoptionAndOfflineGuide() {
        let app = launch()
        tap(app.buttons["training.library"], app); search("俯卧撑", app)
        tap(app.buttons["exercise.row.俯卧撑"], app); tap(app.buttons["exercise.favorite"], app)
        XCTAssertEqual(app.buttons["exercise.favorite"].label, "取消收藏")
        back(app)
        tap(app.segmentedControls["exercise.collection"].buttons["收藏"], app)
        XCTAssertTrue(app.buttons["exercise.row.俯卧撑"].exists)
        XCTAssertEqual(app.staticTexts["exercise.resultCount"].label, "1 个动作")
        capture(app, "v12-favorite-exercises")
        back(app); tap(app.buttons["training.programs"], app)
        tap(app.buttons["program.bodyweight"], app)
        XCTAssertFalse(app.staticTexts["program.adopted"].exists)
        capture(app, "v12-program-preview")
        tap(app.buttons["program.adopt.bodyweight"], app)
        XCTAssertTrue(app.staticTexts["program.adopted"].waitForExistence(timeout: 5))
        tap(app.buttons["program.saved.徒手基础 A"], app)
        XCTAssertEqual(app.staticTexts["template.title"].label, "徒手基础 A")
        tap(app.buttons["template.start"], app)
        XCTAssertTrue(reveal(app.buttons["workout.set.0.0"], app))
        XCTAssertFalse(app.buttons["workout.set.0.0"].label.contains("已完成，"))
        capture(app, "v12-program-workout")
        tap(app.buttons["workout.close"], app)
        back(app); back(app); back(app)
        tap(app.buttons["training.guides"], app); tap(app.buttons["training.guide.targets-and-actual"], app)
        XCTAssertTrue(app.staticTexts["计划是参考"].waitForExistence(timeout: 5))
        capture(app, "v12-recording-guide")
    }

    func testFreeWorkoutStructureAndLargeTypeDarkMode() {
        let app = launch(extra: ["--dark-mode", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        tap(app.buttons["training.freeStart"], app)
        tap(app.buttons["workout.rename"], app)
        tap(app.buttons["workout.clearName"], app)
        app.textFields["workout.nameInput"].tap(); app.textFields["workout.nameInput"].typeText("我的自由训练")
        tap(app.buttons["workout.saveName"], app)
        add("俯卧撑", app); add("平板支撑", app)
        tap(app.buttons["workout.exerciseMenu.0"], app); tap(app.buttons["下移动作"], app)
        tap(app.buttons["workout.timer.0.0"], app); tap(app.buttons["workout.pause"], app)
        tap(app.buttons["workout.exerciseMenu.0"], app); tap(app.buttons["移除动作"], app)
        let confirm = app.buttons["workout.confirmRemoveExercise"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(reveal(app.buttons["workout.set.0.0"], app))
        XCTAssertFalse(app.buttons["workout.timer.0.0"].exists)
        XCTAssertTrue(reveal(app.staticTexts["workout.status"], app))
        XCTAssertEqual(app.staticTexts["workout.status"].label, "训练已暂停")
        XCTAssertEqual(app.staticTexts["workout.started"].label, "我的自由训练")
        capture(app, "v12-free-workout-large-dark")
    }
}
