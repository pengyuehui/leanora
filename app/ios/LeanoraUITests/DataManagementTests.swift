import XCTest

@MainActor final class DataManagementTests: XCTestCase {
    private func launch(reset: Bool = true, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--backup-fixtures", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if reset { app.launchArguments.append("--reset-state") }
        app.launchArguments += extra
        app.launch()
        if app.buttons["onboarding.start"].waitForExistence(timeout: 5) {
            tap(app.buttons["onboarding.start"], app)
            tap(app.buttons["onboarding.next"], app)
            tap(app.buttons["onboarding.finish"], app)
        }
        XCTAssertTrue(app.staticTexts["screen.today"].waitForExistence(timeout: 10))
        app.buttons["我的"].tap(); tap(app.buttons["settings.data"], app)
        reveal(app.buttons["backup.export"], app)
        return app
    }
    private func tap(_ element: XCUIElement, _ app: XCUIApplication) {
        reveal(element, app)
        element.tap()
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<10 { if element.exists && element.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func selectFile(_ name: String, app: XCUIApplication) {
        tap(app.buttons["backup.import"], app)
        let file = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        if !file.waitForExistence(timeout: 3) {
            let browse = app.buttons.matching(NSPredicate(format: "label IN %@", ["Browse", "浏览"])).firstMatch
            if browse.exists { browse.tap() }
            let onPhone = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["On My iPhone", "我的 iPhone"])).firstMatch
            if onPhone.waitForExistence(timeout: 3) { onPhone.tap() }
            let folder = app.staticTexts["Leanora"]
            if folder.waitForExistence(timeout: 3) { folder.tap() }
        }
        XCTAssertTrue(file.waitForExistence(timeout: 5), app.debugDescription)
        let cell = app.cells.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(cell.exists)
        cell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
    }

    func testRealFileImportPreviewsCommitsAndSurvivesRelaunch() {
        let app = launch()
        capture(app, "u2-data-management")
        selectFile("Leanora-valid", app: app)
        reveal(app.buttons["backup.confirm"], app)
        capture(app, "u2-import-preview")
        app.buttons["backup.confirm"].tap()
        XCTAssertTrue(app.staticTexts["backup.notice"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["backup.notice"].label.contains("新增 1"))
        capture(app, "u2-import-complete")
        app.terminate()
        let reopened = launch(reset: false)
        XCTAssertTrue(reopened.staticTexts["backup.count"].label.contains("2 条"))
    }

    func testInvalidFileShowsErrorAndDoesNotChangeRecordCount() {
        let app = launch()
        selectFile("Leanora-invalid", app: app)
        XCTAssertTrue(app.staticTexts["backup.error"].waitForExistence(timeout: 5) || app.otherElements["backup.error"].exists)
        XCTAssertTrue(app.staticTexts["backup.count"].label.contains("1 条"))
        XCTAssertFalse(app.buttons["backup.confirm"].exists)
        capture(app, "u2-invalid-backup")
    }

    func testExportOpensNativeSavePanelAndCanCancel() {
        let app = launch()
        tap(app.buttons["backup.export"], app)
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "取消"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), app.debugDescription)
        capture(app, "u2-export-file-panel")
        cancel.tap()
        XCTAssertTrue(app.buttons["backup.export"].exists)
    }

    func testExportSavesRealJSONAndCanImportItAgain() {
        let app = launch()
        tap(app.buttons["backup.export"], app)
        let save = app.buttons.matching(NSPredicate(format: "label IN %@", ["Save", "保存"])).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5), app.debugDescription)
        // The native panel can save the default name; replacement is explicitly
        // confirmed only inside this app's isolated UI-test Documents directory.
        save.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let replace = app.buttons.matching(NSPredicate(format: "label IN %@", ["Replace", "替换"])).firstMatch
        for _ in 0..<3 {
            if app.staticTexts["backup.notice"].waitForExistence(timeout: 1) { break }
            if replace.exists { replace.tap() }
            else if save.exists && save.isHittable { save.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        }
        XCTAssertTrue(app.staticTexts["backup.notice"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["backup.notice"].label.contains("备份已导出"))
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        selectFile("Leanora-" + formatter.string(from: Date()), app: app)
        tap(app.buttons["backup.confirm"], app)
        XCTAssertTrue(app.staticTexts["backup.notice"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["backup.notice"].label.contains("新增 0"))
    }

    func testStartupFailureOffersRetryWithoutResettingBusinessStore() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "--store-open-failed"]
        app.launch()
        XCTAssertTrue(app.staticTexts["store.error"].waitForExistence(timeout: 8))
        capture(app, "u2-store-open-failure")
        app.buttons["store.retry"].tap()
        XCTAssertTrue(app.buttons["onboarding.start"].waitForExistence(timeout: 8))
    }

    func testDataManagementLargeTypeAndDarkAppearance() {
        let app = launch(extra: ["--dark-mode", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        reveal(app.buttons["backup.import"], app)
        capture(app, "u2-data-large-dark")
        XCTAssertTrue(app.buttons["backup.import"].isHittable)
    }
}
