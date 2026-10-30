import XCTest

@MainActor final class TemplateEditorTests: XCTestCase {
    private func launch(reset: Bool = true, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + extra
        if reset { app.launchArguments.append("--reset-state") }
        app.launch()
        if app.buttons["onboarding.start"].waitForExistence(timeout: 5) {
            tap(app.buttons["onboarding.start"], app); tap(app.buttons["onboarding.next"], app); tap(app.buttons["onboarding.finish"], app)
        }
        XCTAssertTrue(app.staticTexts["screen.today"].waitForExistence(timeout: 8))
        app.buttons["训练"].tap()
        return app
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        func reachable() -> Bool {
            guard element.exists, element.isHittable else { return false }
            var bottom = app.frame.maxY - 40
            let finish = app.buttons["workout.finish"]
            if element.identifier.hasPrefix("workout."), !element.identifier.hasPrefix("workout.confirm"), !["workout.finish", "workout.restSkip"].contains(element.identifier), finish.exists && finish.isHittable {
                bottom = min(bottom, finish.frame.minY - 8)
            }
            return element.frame.maxY < bottom && element.frame.midY > 20
        }
        for _ in 0..<15 { if reachable() { return }; app.swipeUp() }
        for _ in 0..<18 { if reachable() { return }; app.swipeDown() }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }
    private func tap(_ element: XCUIElement, _ app: XCUIApplication) { reveal(element, app); element.tap() }
    private func back(_ app: XCUIApplication) {
        if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() }
        else { app.navigationBars.buttons.element(boundBy: 0).tap() }
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func search(_ name: String, app: XCUIApplication) {
        let field = app.searchFields.firstMatch
        if !field.waitForExistence(timeout: 2) {
            let searchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "搜索", "Search")).firstMatch
            if searchButton.exists { searchButton.tap() }
        }
        XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription); field.tap(); field.typeText(name)
        let submit = app.keyboards.buttons.matching(NSPredicate(format: "label IN %@", ["Search", "搜索"])).firstMatch
        if submit.exists { submit.tap() }
    }
    private func createTemplate(_ name: String, exercises: [String], today: Bool = false, app: XCUIApplication) {
        tap(app.buttons["training.newTemplate"], app)
        let field = app.textFields["template.name"]; XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(name)
        if app.buttons["template.keyboardDone"].exists { app.buttons["template.keyboardDone"].tap() }
        for exercise in exercises {
            tap(app.buttons["template.addExercise"], app); search(exercise, app: app)
            tap(app.buttons["exercise.select.\(exercise)"], app)
        }
        if today {
            let day = (Calendar.current.component(.weekday, from: Date()) + 5) % 7 + 1
            let toggle = app.switches["template.weekday.\(day)"]; reveal(toggle, app)
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            XCTAssertEqual(toggle.value as? String, "1", "The chosen training day must be enabled before saving")
        }
        tap(app.buttons["template.save"], app)
        tap(app.buttons["training.template.\(name)"], app)
    }

    func testCatalogSearchEquipmentFilterAndSource() {
        let app = launch(); tap(app.buttons["training.library"], app)
        search("BENCH", app: app)
        let total = Int(app.staticTexts["exercise.resultCount"].label.filter(\.isNumber)) ?? 0
        XCTAssertGreaterThan(total, 0)
        tap(app.buttons["exercise.equipment"], app)
        let option = app.buttons["哑铃"]
        if option.exists { option.tap() } else { app.staticTexts["哑铃"].tap() }
        let filtered = Int(app.staticTexts["exercise.resultCount"].label.filter(\.isNumber)) ?? 0
        XCTAssertGreaterThan(filtered, 0); XCTAssertLessThan(filtered, total)
        XCTAssertFalse(app.buttons["exercise.row.杠铃卧推"].exists)
        tap(app.buttons["exercise.row.哑铃卧推"], app)
        reveal(app.staticTexts["exercise.source"], app)
        XCTAssertTrue(app.staticTexts["exercise.source"].label.contains("Leanora 原创"))
        capture(app, "u3-exercise-source")
    }

    func testDuplicateItemsTargetsReorderCopyAndRelaunch() {
        let app = launch(); createTemplate("力量模板", exercises: ["杠铃卧推", "杠铃卧推"], app: app)
        tap(app.buttons["template.edit"], app)
        tap(app.buttons["template.item.0"], app)
        let load = app.textFields["targets.load"]; load.tap(); load.typeText("20")
        app.buttons["targets.keyboardDone"].tap(); tap(app.buttons["targets.save"], app)
        tap(app.buttons["template.itemMenu.0"], app); app.buttons["下移"].tap()
        capture(app, "u3-template-reordered")
        tap(app.buttons["template.save"], app)
        tap(app.buttons["template.edit"], app); tap(app.buttons["template.item.1"], app)
        XCTAssertEqual(app.textFields["targets.load"].value as? String, "20")
        app.buttons["targets.cancel"].tap(); app.buttons["template.cancel"].tap()
        tap(app.buttons["template.copy"], app)
        back(app)
        XCTAssertTrue(app.buttons["training.template.力量模板 · 副本"].exists)
        app.terminate(); let reopened = launch(reset: false)
        XCTAssertTrue(reopened.buttons["training.template.力量模板"].exists)
        XCTAssertTrue(reopened.buttons["training.template.力量模板 · 副本"].exists)
        capture(reopened, "u3-templates-persisted")
    }

    func testEmptyTemplateCannotStart() {
        let app = launch(); createTemplate("空模板", exercises: [], app: app)
        XCTAssertFalse(app.buttons["template.start"].isEnabled)
        capture(app, "u3-empty-template")
    }

    func testSupersetPairingPersistsIntoWorkoutSnapshot() {
        let app = launch(); createTemplate("超级组模板", exercises: ["俯卧撑", "自重深蹲"], app: app)
        tap(app.buttons["template.edit"], app); tap(app.buttons["template.itemMenu.0"], app)
        app.buttons["与下一动作组成超级组"].tap(); tap(app.buttons["template.save"], app)
        tap(app.buttons["template.start"], app)
        let label = app.staticTexts["超级组 · 同轮两个动作完成后休息"].firstMatch
        for _ in 0..<10 {
            if label.exists && label.isHittable { break }
            app.collectionViews.allElementsBoundByIndex.last?.swipeUp()
        }
        XCTAssertTrue(label.exists); capture(app, "u4-superset-snapshot")
    }

    func testCustomExerciseCanBeArchivedWithoutDeletion() {
        let app = launch(); tap(app.buttons["training.library"], app); tap(app.buttons["exercise.new"], app)
        let name = app.textFields["exercise.name"]; name.tap(); name.typeText("我的推举")
        tap(app.buttons["exercise.save"], app)
        search("我的推举", app: app); tap(app.buttons["exercise.row.我的推举"], app)
        tap(app.buttons["exercise.archive"], app); app.buttons["exercise.confirmArchive"].firstMatch.tap()
        capture(app, "u3-custom-archived")
        XCTAssertTrue(app.buttons["exercise.archive"].label.contains("恢复"))
    }

    func testOneOffMovePersistsAndLeavesTodayEmpty() {
        let app = launch(); createTemplate("周计划模板", exercises: ["平板支撑"], today: true, app: app)
        back(app); tap(app.buttons["training.weekly"], app)
        tap(app.buttons["weekly.move.周计划模板"], app)
        tap(app.buttons["weekly.moveTomorrow"], app); tap(app.buttons["weekly.saveMove"], app)
        capture(app, "u3-one-off-move")
        tap(app.buttons["weekly.today"], app)
        XCTAssertTrue(app.staticTexts["weekly.empty"].exists)
        app.terminate(); let reopened = launch(reset: false)
        tap(reopened.buttons["training.weekly"], reopened)
        XCTAssertTrue(reopened.staticTexts["weekly.empty"].exists)
        tap(reopened.buttons["weekly.next"], reopened)
        XCTAssertTrue(reopened.buttons["weekly.move.周计划模板"].exists)
        XCTAssertFalse(reopened.buttons["weekly.start.周计划模板"].isEnabled)
    }

    func testStartsTodayAndReturnsToSameWorkoutAfterRelaunch() {
        let app = launch(); createTemplate("当天训练", exercises: ["哑铃肩推"], today: true, app: app)
        back(app); tap(app.buttons["training.weekly"], app)
        tap(app.buttons["weekly.start.当天训练"], app)
        XCTAssertTrue(app.staticTexts["workout.started"].waitForExistence(timeout: 5))
        capture(app, "u3-started-workout")
        app.buttons["workout.close"].tap(); app.terminate()
        let reopened = launch(reset: false)
        tap(reopened.buttons["training.active"], reopened)
        XCTAssertTrue(reopened.staticTexts["workout.started"].exists)
        tap(reopened.buttons["workout.abandon"], reopened); reopened.buttons["确认放弃"].firstMatch.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: reopened.buttons["training.active"])
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
    }

    func testLargeDarkTrainingAndExerciseLibrary() {
        let app = launch(extra: ["--dark-mode", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        tap(app.buttons["training.library"], app)
        search("平板支撑", app: app)
        reveal(app.buttons["exercise.row.平板支撑"], app)
        capture(app, "u3-library-large-dark")
        app.buttons["exercise.row.平板支撑"].tap()
        reveal(app.staticTexts["exercise.source"], app)
        XCTAssertTrue(app.staticTexts["exercise.source"].isHittable)
    }
}
