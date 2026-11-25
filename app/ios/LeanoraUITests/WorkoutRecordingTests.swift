import XCTest

@MainActor final class WorkoutRecordingTests: XCTestCase {
    private func launch(reset: Bool = true, extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--store-screenshots", "--workout-recording-fixture", "--notifications-denied", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + extra
        if reset { app.launchArguments.append("--reset-state") }
        app.launch(); XCTAssertTrue(app.staticTexts["screen.today"].waitForExistence(timeout: 60), app.debugDescription)
        return app
    }
    private func openWorkout(_ app: XCUIApplication) {
        app.tabBars.buttons["动作"].tap(); tap(app.buttons["exercise.training"], app)
        tap(app.buttons["training.active"], app)
        XCTAssertTrue(app.staticTexts["workout.started"].waitForExistence(timeout: 8))
    }
    private func tap(_ element: XCUIElement, _ app: XCUIApplication) {
        reveal(element, app, performTap: true)
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication, performTap: Bool = false) {
        for attempt in 0..<20 {
            if element.exists && element.isEnabled {
                let frame = element.frame
                var bottom = app.frame.maxY - 30
                if app.keyboards.firstMatch.exists { bottom = min(bottom, app.keyboards.firstMatch.frame.minY) }
                let footerIDs = ["workout.finish", "workout.undo", "workout.restExtend", "workout.restSkip"]
                let finish = app.buttons["workout.finish"]
                if !footerIDs.contains(element.identifier), finish.exists, finish.isHittable { bottom = min(bottom, finish.frame.minY - 8) }
                let visible = frame.intersection(CGRect(x: 0, y: 90, width: app.frame.width, height: max(0, bottom - 90)))
                if (!performTap && visible.height >= min(44, frame.height) && visible.width > 0) ||
                    (performTap && element.isHittable && frame.minY >= 90 && frame.maxY <= bottom) {
                    if performTap { element.tap() }
                    return
                }
            }
            let down = (element.exists && element.frame.minY < 90) || (!element.exists && (3..<12).contains(attempt))
            var bottom = app.frame.maxY - 100
            let finish = app.buttons["workout.finish"]
            if finish.exists, finish.isHittable { bottom = min(bottom, finish.frame.minY - 110) }
            if app.keyboards.firstMatch.exists { bottom = min(bottom, app.keyboards.firstMatch.frame.minY - 35) }
            let top = min(220.0, bottom - 90)
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.midX, dy: down ? top : bottom))
            let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.midX, dy: down ? bottom : top))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTFail("Cannot tap \(element)\n\(app.debugDescription)")
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let item = XCTAttachment(screenshot: app.screenshot()); item.name = name; item.lifetime = .keepAlways; add(item)
    }
    private func hideKeyboard(_ app: XCUIApplication) {
        if app.buttons["workout.keyboardDone"].exists { app.buttons["workout.keyboardDone"].tap() }
    }
    private func reuse(_ app: XCUIApplication) { tap(app.buttons["workout.reusePrevious.0"], app) }

    func testThreeInlineSetsWithoutEditorThenUndoAndRelaunch() {
        var app = launch(); openWorkout(app)
        reuse(app)
        for index in 0..<3 {
            let field = app.textFields["workout.input.0.\(index).load"]
            XCTAssertTrue(field.waitForExistence(timeout: 5)); XCTAssertEqual(field.value as? String, "20")
            tap(app.buttons["workout.complete.0.\(index)"], app)
            XCTAssertFalse(app.buttons["set.save"].exists)
        }
        hideKeyboard(app); capture(app, "v16-inline-three-completed")
        tap(app.buttons["workout.undo"], app)
        XCTAssertTrue(app.textFields["workout.input.0.2.load"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["workout.input.0.2.load"].value as? String, "20")
        XCTAssertFalse(app.staticTexts["workout.rest"].exists)
        capture(app, "v16-inline-undo")
        app.terminate(); app = launch(reset: false); openWorkout(app)
        reveal(app.textFields["workout.input.0.2.load"], app)
        XCTAssertTrue(app.textFields["workout.input.0.2.load"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["workout.input.0.0.load"].exists)
    }

    func testInvalidInlineInputStaysInRowAndCanRetry() {
        let app = launch(); openWorkout(app)
        let load = app.textFields["workout.input.0.0.load"], reps = app.textFields["workout.input.0.0.repetitions"]
        tap(load, app); load.typeText("25")
        tap(reps, app); reps.typeText("0")
        hideKeyboard(app); tap(app.buttons["workout.complete.0.0"], app)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "workout.rowError.0.0").firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(load.value as? String, "25")
        tap(reps, app); reps.typeText(XCUIKeyboardKey.delete.rawValue + "8")
        hideKeyboard(app); tap(app.buttons["workout.complete.0.0"], app)
        XCTAssertFalse(app.textFields["workout.input.0.0.load"].exists)
        hideKeyboard(app); capture(app, "v16-inline-validation-retry")
    }

    func testRestPausePersistsAcrossTerminationAndResume() {
        var app = launch(); openWorkout(app); reuse(app)
        tap(app.buttons["workout.complete.0.0"], app); hideKeyboard(app)
        tap(app.buttons["workout.pause"], app)
        XCTAssertEqual(app.staticTexts["workout.status"].label, "训练已暂停", app.debugDescription)
        XCTAssertTrue(app.staticTexts["workout.restPaused"].waitForExistence(timeout: 5))
        capture(app, "v16-rest-paused")
        app.terminate(); app = launch(reset: false); openWorkout(app)
        XCTAssertTrue(app.staticTexts["workout.restPaused"].waitForExistence(timeout: 5))
        tap(app.buttons["workout.pause"], app)
        XCTAssertTrue(app.staticTexts["workout.rest"].waitForExistence(timeout: 5))
        capture(app, "v16-rest-resumed")
    }

    func testReplacementPreviewCancelThenConfirmPreservesCompletedSet() {
        let app = launch(); openWorkout(app); reuse(app)
        tap(app.buttons["workout.complete.0.0"], app); hideKeyboard(app)
        func choose() {
            tap(app.buttons["workout.exerciseMenu.0"], app)
            tap(app.buttons["workout.replace.0"], app)
            let search = app.searchFields.firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("哑铃卧推")
            let submit = app.keyboards.buttons.matching(NSPredicate(format: "label IN %@", ["搜索", "Search"])).firstMatch
            if submit.exists { submit.tap() }
            tap(app.buttons["replacement.row.哑铃卧推"], app)
            XCTAssertTrue(app.buttons["replacement.confirm"].waitForExistence(timeout: 5))
        }
        choose(); capture(app, "v16-replacement-preview")
        tap(app.buttons["replacement.cancel"], app)
        XCTAssertTrue(app.textFields["workout.input.0.1.load"].waitForExistence(timeout: 5))
        choose(); tap(app.buttons["replacement.confirm"], app)
        reveal(app.textFields["workout.input.1.0.load"], app)
        XCTAssertTrue(app.textFields["workout.input.1.0.load"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["workout.input.0.0.load"].exists)
        XCTAssertFalse(app.textFields["workout.input.0.1.load"].exists)
        capture(app, "v16-replacement-completed")
    }

    func testLargeTypeDarkInlineLayoutAndAdvancedEditor() {
        let app = launch(extra: ["--dark-mode", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        openWorkout(app)
        let field = app.textFields["workout.input.0.0.load"]
        tap(field, app); field.typeText("30")
        hideKeyboard(app); capture(app, "v16-inline-large-dark")
        tap(app.buttons["workout.set.0.0"], app)
        XCTAssertTrue(app.textFields["set.load"].waitForExistence(timeout: 5)); XCTAssertEqual(app.textFields["set.load"].value as? String, "30")
        XCTAssertTrue(app.segmentedControls.count > 0 || app.staticTexts["主观强度"].exists || app.buttons["set.save"].exists)
    }

    func testHealthDiagnosticIsVisibleAfterRequest() {
        let app = launch(extra: ["--health-failed"])
        app.tabBars.buttons["我的"].tap(); tap(app.buttons["settings.health"], app)
        tap(app.buttons["health.request"], app)
        XCTAssertTrue(app.staticTexts["health.failureCode"].waitForExistence(timeout: 5))
        tap(app.buttons["授权诊断"], app)
        let diagnostic = app.descendants(matching: .any).matching(identifier: "health.diagnostic").firstMatch
        reveal(diagnostic, app)
        XCTAssertTrue(diagnostic.exists)
        capture(app, "v16-health-diagnostic")
    }
}
