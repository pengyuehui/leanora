import XCTest

@MainActor final class StoreScreenshotTests: XCTestCase {
    func testCaptureChineseStoreScreenshots() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "--store-screenshots", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["today.start"].waitForExistence(timeout: 40), app.debugDescription)
        XCTAssertTrue(app.staticTexts["nutrition.energy"].exists)
        capture(app, "store-01-today")
        app.tabBars.buttons["动作"].tap()
        tap(app.buttons["exercise.region.胸"], in: app)
        capture(app, "store-02-exercises")
        app.buttons["exercise.training"].tap()
        tap(app.buttons["training.active"], in: app)
        XCTAssertTrue(app.buttons["workout.pause"].label.contains("继续"))
        reveal(app.buttons["workout.set.0.0"], in: app)
        capture(app, "store-03-workout")
        tap(app.buttons["workout.close"], in: app)
        waitGone(app.buttons["workout.close"])
        app.tabBars.buttons["饮食"].tap()
        XCTAssertTrue(app.staticTexts["nutrition.goal"].waitForExistence(timeout: 5))
        capture(app, "store-04-nutrition")
        tap(app.buttons["diet.entry.全脂牛奶（添加维生素 D）"], in: app)
        XCTAssertTrue(app.staticTexts["food.source"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["food.source"].label.contains("USDA"))
        capture(app, "store-05-portion")
        app.buttons["取消"].tap()
        waitGone(app.buttons["portion.save"])
        app.tabBars.buttons["历史"].tap()
        app.segmentedControls["history.category"].buttons["体重体脂"].tap()
        app.segmentedControls["history.mode"].buttons["统计"].tap()
        capture(app, "store-06-trends")
        app.tabBars.buttons["我的"].tap()
        tap(app.buttons["settings.health"], in: app)
        XCTAssertTrue(app.switches["health.auto"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.switches["health.auto"].value as? String, "0")
        capture(app, "store-07-health")
    }
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        reveal(element, in: app)
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists && element.isHittable && element.frame.maxY < app.frame.maxY - 40 {
                return
            }
            app.swipeUp()
        }
        for _ in 0..<16 {
            if element.exists && element.isHittable && element.frame.maxY < app.frame.maxY - 40 { return }
            app.swipeDown()
        }
        XCTFail("Screenshot flow element unavailable: \(app.debugDescription)")
    }
    private func waitGone(_ element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
