import XCTest

@MainActor final class ExerciseGuidanceTests: XCTestCase {
    private func launch(extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + extra
        app.launch()
        if app.buttons["onboarding.start"].waitForExistence(timeout: 5) {
            tap(app.buttons["onboarding.start"], app); tap(app.buttons["onboarding.next"], app); tap(app.buttons["onboarding.finish"], app)
        }
        XCTAssertTrue(app.staticTexts["screen.today"].waitForExistence(timeout: 10))
        app.buttons["训练"].tap()
        return app
    }
    private func tap(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<18 {
            if element.exists && element.isHittable { element.tap(); return }
            app.swipeUp()
        }
        XCTFail("Element unavailable: \(element)")
    }
    private func search(_ name: String, _ app: XCUIApplication) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(name)
        let submit = app.keyboards.buttons.matching(NSPredicate(format: "label IN %@", ["Search", "搜索"])).firstMatch
        if submit.exists { submit.tap() }
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let proof = XCTAttachment(screenshot: app.screenshot()); proof.name = name; proof.lifetime = .keepAlways; add(proof)
    }
    private func back(_ app: XCUIApplication) {
        if app.buttons["BackButton"].exists { app.buttons["BackButton"].tap() }
        else { app.navigationBars.buttons.element(boundBy: 0).tap() }
    }

    func testPhotoGuidePagingLargeImageAndSource() {
        let app = launch(); tap(app.buttons["training.library"], app)
        search("杠铃卧推", app); tap(app.buttons["exercise.row.杠铃卧推"], app)
        XCTAssertTrue(app.buttons["exercise.guide.zoom.0"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["exercise.guide.page"].label, "1 / 2")
        capture(app, "exercise-photo-guide")
        app.buttons["exercise.guide.next"].tap()
        XCTAssertEqual(app.staticTexts["exercise.guide.page"].label, "2 / 2")
        app.buttons["exercise.guide.zoom.1"].tap()
        XCTAssertTrue(app.buttons["exercise.guide.closeImage"].waitForExistence(timeout: 5))
        capture(app, "exercise-photo-large")
        app.buttons["exercise.guide.closeImage"].tap()
        XCTAssertEqual(app.staticTexts["exercise.guide.page"].label, "2 / 2")
        tap(app.staticTexts["exercise.guide.source"], app)
        XCTAssertEqual(app.staticTexts["exercise.guide.source"].label, "Free Exercise DB")
        capture(app, "exercise-source-credit")
    }

    func testPreviewWhileChoosingDoesNotAddExerciseAndWorkoutGuideKeepsSession() {
        let app = launch(); tap(app.buttons["training.newTemplate"], app)
        let name = app.textFields["template.name"]; name.tap(); name.typeText("指导入口验证")
        app.buttons["template.keyboardDone"].tap()
        tap(app.buttons["template.addExercise"], app); search("帕洛夫抗旋转推", app)
        tap(app.buttons["exercise.info.帕洛夫抗旋转推"], app)
        XCTAssertTrue(app.buttons["exercise.guide.zoom.0"].waitForExistence(timeout: 5))
        capture(app, "exercise-picker-preview")
        back(app)
        XCTAssertTrue(app.buttons["exercise.select.帕洛夫抗旋转推"].waitForExistence(timeout: 5))
        tap(app.buttons["exercise.select.帕洛夫抗旋转推"], app)
        XCTAssertTrue(app.buttons["template.item.0"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["template.item.1"].exists)
        tap(app.buttons["template.save"], app); tap(app.buttons["training.template.指导入口验证"], app)
        tap(app.buttons["template.start"], app); tap(app.buttons["workout.guide.0"], app)
        XCTAssertTrue(app.buttons["exercise.guide.zoom.0"].waitForExistence(timeout: 5))
        capture(app, "exercise-workout-guide")
        app.buttons["workout.closeGuide"].tap()
        XCTAssertTrue(app.buttons["workout.set.0.0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["workout.started"].exists)
    }

    func testIllustrationGuideInDarkModeWithLargeType() {
        let app = launch(extra: ["--dark-mode", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        tap(app.buttons["training.library"], app); search("鸟狗式", app)
        tap(app.buttons["exercise.row.鸟狗式"], app)
        XCTAssertTrue(app.buttons["exercise.guide.zoom.0"].waitForExistence(timeout: 5))
        capture(app, "exercise-illustration-large-dark")
        tap(app.buttons["exercise.guide.next"], app)
        XCTAssertEqual(app.staticTexts["exercise.guide.page"].label, "2 / 3")
    }
}
