import XCTest

@MainActor final class WorkoutRecoveryTests: XCTestCase {
    private func launch(reset: Bool = true, extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + extra
        if reset { app.launchArguments.append("--reset-state") }; app.launch()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.buttons["onboarding.start"].exists || app.staticTexts["screen.today"].exists }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 60), .completed)
        if app.buttons["onboarding.start"].exists {
            tap(app.buttons["onboarding.start"], app); tap(app.buttons["onboarding.next"], app); tap(app.buttons["onboarding.finish"], app)
        }
        XCTAssertTrue(app.staticTexts["screen.today"].waitForExistence(timeout: 8)); app.buttons["训练"].tap(); return app
    }
    private func tap(_ element: XCUIElement, _ app: XCUIApplication) {
        reveal(element, app); element.tap()
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        func reachable() -> Bool {
            guard element.exists else { return false }
            let frame = element.frame
            guard frame.minY.isFinite, frame.width > 0, frame.height > 0 else { return false }
            var bottom = app.frame.maxY - 40
            let finish = app.buttons["workout.finish"]
            if element.identifier.hasPrefix("workout."), !element.identifier.hasPrefix("workout.confirm"), !["workout.finish", "workout.restSkip"].contains(element.identifier), finish.exists && finish.isHittable {
                bottom = min(bottom, finish.frame.minY - 8)
            }
            guard frame.maxY < bottom, frame.midY > 20 else { return false }
            // TimelineView text can have valid visible geometry while XCTest
            // cannot derive an activation point. It is read, never tapped.
            return element.elementType == .staticText || element.isHittable
        }
        func scroll(_ up: Bool) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: up ? 0.65 : 0.35))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: up ? 0.35 : 0.65)), withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        if element.waitForExistence(timeout: 3), reachable() { return }
        for _ in 0..<18 { if reachable() { return }; scroll(true) }
        for _ in 0..<28 { if reachable() { return }; scroll(false) }
        XCTFail(app.debugDescription)
    }
    private func create(_ name: String, exercise: String, app: XCUIApplication) {
        tap(app.buttons["training.newTemplate"], app)
        let nameField = app.textFields["template.name"]; XCTAssertTrue(nameField.waitForExistence(timeout: 5)); nameField.tap(); nameField.typeText(name)
        app.buttons["template.keyboardDone"].tap(); tap(app.buttons["template.addExercise"], app)
        let search = app.searchFields.firstMatch
        if !search.waitForExistence(timeout: 2) { app.buttons.matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "搜索", "Search")).firstMatch.tap() }
        search.tap(); search.typeText(exercise)
        let submit = app.keyboards.buttons.matching(NSPredicate(format: "label IN %@", ["Search", "搜索"])).firstMatch; if submit.exists { submit.tap() }
        tap(app.buttons["exercise.select.\(exercise)"], app); tap(app.buttons["template.save"], app)
        tap(app.buttons["training.template.\(name)"], app); tap(app.buttons["template.start"], app)
        XCTAssertTrue(app.staticTexts["workout.started"].waitForExistence(timeout: 5))
    }
    private func capture(_ app: XCUIApplication, _ name: String) { let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a) }
    private func waitGone(_ element: XCUIElement) { XCTAssertTrue(NSPredicate(format: "exists == false").evaluate(with: element) || XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)], timeout: 5) == .completed) }
    func testRecordPauseKillRecoverFinishAndEditHistory() {
        var app = launch(extra: ["--notifications-denied"]); create("逐组验收", exercise: "杠铃卧推", app: app)
        tap(app.buttons["workout.set.0.0"], app)
        app.textFields["set.load"].tap(); app.textFields["set.load"].typeText("20")
        app.textFields["set.reps"].tap(); app.textFields["set.reps"].typeText("8")
        app.buttons["set.keyboardDone"].tap(); app.buttons["set.save"].tap()
        XCTAssertTrue(app.buttons["workout.complete.0.0"].waitForExistence(timeout: 5))
        tap(app.buttons["workout.complete.0.0"], app)
        reveal(app.staticTexts["workout.rest"], app)
        tap(app.buttons["workout.pause"], app); XCTAssertEqual(app.staticTexts["workout.status"].label, "训练已暂停")
        capture(app, "u4-paused-set-rest")
        app.terminate(); app = launch(reset: false, extra: ["--notifications-denied"])
        tap(app.buttons["training.active"], app); XCTAssertEqual(app.staticTexts["workout.status"].label, "训练已暂停")
        tap(app.buttons["workout.pause"], app); XCTAssertEqual(app.staticTexts["workout.status"].label, "训练进行中")
        capture(app, "u4-recovered-session")
        tap(app.buttons["workout.finish"], app); app.buttons["workout.confirmFinish"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitGone(app.buttons["workout.close"])
        app.buttons["训练"].tap()
        if !app.buttons["training.history"].exists {
            if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() }
            else if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
        }
        tap(app.buttons["training.history"], app); tap(app.buttons["history.逐组验收"], app)
        XCTAssertEqual(app.staticTexts["workout.status"].label, "训练已完成")
        tap(app.buttons["workout.set.0.0"], app); tap(app.buttons["set.clear.load"], app)
        app.textFields["set.load"].tap(); app.textFields["set.load"].typeText("25")
        app.buttons["set.keyboardDone"].tap(); app.buttons["set.save"].tap()
        for _ in 0..<10 { if app.staticTexts["工作组容量：200 kg·次"].exists { break }; app.collectionViews.allElementsBoundByIndex.last?.swipeUp() }
        XCTAssertTrue(app.staticTexts["工作组容量：200 kg·次"].exists, app.debugDescription)
        capture(app, "u4-history-edited-volume")
    }
    func testDurationTimerSurvivesPauseAndRelaunch() {
        var app = launch(); create("计时验收", exercise: "平板支撑", app: app)
        tap(app.buttons["workout.timer.0.0"], app)
        tap(app.buttons["workout.pause"], app); capture(app, "u4-timer-paused")
        app.terminate(); app = launch(reset: false)
        tap(app.buttons["training.active"], app)
        XCTAssertEqual(app.staticTexts["workout.status"].label, "训练已暂停")
        tap(app.buttons["workout.pause"], app)
        reveal(app.buttons["workout.timer.0.0"], app)
        XCTAssertEqual(app.buttons["workout.timer.0.0"].label, "停止计时")
        tap(app.buttons["workout.timer.0.0"], app)
        tap(app.buttons["workout.complete.0.0"], app)
        reveal(app.staticTexts["workout.rest"], app); capture(app, "u4-duration-complete")
    }
    // Run separately on a clean simulator: permission grants conflict with the
    // onboarding suite's explicit denial scenario on the same installation.
    func testSystemRestReminderAuthorizationAndScheduling() {
        let app = launch(extra: ["--system-permissions"]); create("系统休息提醒", exercise: "杠铃卧推", app: app)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if app.buttons["workout.notifications"].exists {
            tap(app.buttons["workout.notifications"], app)
            let allow = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["允许", "Allow"])).firstMatch
            if allow.waitForExistence(timeout: 3) { allow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        }
        tap(app.buttons["workout.set.0.0"], app)
        app.textFields["set.load"].tap(); app.textFields["set.load"].typeText("20")
        app.textFields["set.reps"].tap(); app.textFields["set.reps"].typeText("8")
        app.buttons["set.keyboardDone"].tap(); app.buttons["set.save"].tap()
        tap(app.buttons["workout.complete.0.0"], app)
        reveal(app.staticTexts["workout.rest"], app)
        if app.buttons["workout.close"].exists { tap(app.buttons["workout.close"], app) }
        else { tap(app.buttons["BackButton"], app) }
        XCTAssertTrue(app.buttons["我的"].waitForExistence(timeout: 5))
        app.buttons["我的"].tap(); tap(app.buttons["settings.notifications"], app)
        XCTAssertTrue(app.staticTexts["已允许通知"].waitForExistence(timeout: 5))
        for _ in 0..<10 { if app.staticTexts["notifications.pending"].exists { break }; app.collectionViews.allElementsBoundByIndex.last?.swipeUp() }
        XCTAssertTrue(app.staticTexts["notifications.pending"].label.contains("1"), app.debugDescription)
        capture(app, "u4-system-authorized-pending-reminder")
    }
}
