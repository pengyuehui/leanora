import XCTest
@testable import Leanora

@MainActor final class PreferenceTests: XCTestCase {
    func testOptionalGoalsAndUnitsSurviveRelaunch() throws {
        let name = "Leanora.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let first = AppPreferences(defaults: defaults)
        try first.save(weight: .pounds, distance: .miles, days: 4, energyText: " 2300 ")
        first.finishOnboarding()
        first.markHealthRequestProcessed()
        let restored = AppPreferences(defaults: defaults)
        XCTAssertEqual(restored.values.weightUnit, .pounds)
        XCTAssertEqual(restored.values.distanceUnit, .miles)
        XCTAssertEqual(restored.values.weeklyTrainingDays, 4)
        XCTAssertEqual(restored.values.dailyEnergyGoal, 2300)
        XCTAssertTrue(restored.hasCompletedOnboarding)
        XCTAssertNotNil(restored.lastHealthRequest)
        try restored.save(weight: .kilograms, distance: .kilometers, days: nil, energyText: "")
        XCTAssertNil(AppPreferences(defaults: defaults).values.dailyEnergyGoal)
    }

    func testInvalidInputDoesNotOverwriteSavedPreferences() throws {
        let name = "Leanora.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = AppPreferences(defaults: defaults)
        try preferences.save(weight: .kilograms, distance: .kilometers, days: 3, energyText: "2000")
        for input in ["-1", "0", "20001", "2.5", "1e3", "NaN", "99999999999999999999999"] {
            XCTAssertThrowsError(try preferences.save(weight: .pounds, distance: .miles, days: nil, energyText: input))
            XCTAssertEqual(preferences.values.dailyEnergyGoal, 2000)
            XCTAssertEqual(preferences.values.weightUnit, .kilograms)
        }
        XCTAssertThrowsError(try preferences.save(weight: .pounds, distance: .miles, days: 8, energyText: ""))
    }

    func testCorruptPreferencesHaveVisibleRecoveryNotice() {
        let name = "Leanora.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(Data("invalid".utf8), forKey: "preferences.v1")
        let preferences = AppPreferences(defaults: defaults)
        XCTAssertEqual(preferences.values, PreferenceValues())
        XCTAssertNotNil(preferences.storageNotice)
        XCTAssertFalse(preferences.hasCompletedOnboarding)
    }
}

@MainActor final class FakeHealthAuthorizer: HealthAuthorizing {
    var isAvailable = true
    var applicationState = "active"
    var prompt = HealthPromptStatus.unknown
    var holdPrompt = false
    var promptContinuation: CheckedContinuation<HealthPromptStatus, Never>?
    func promptStatus(_ selection: HealthAccessSelection) async -> HealthPromptStatus {
        if holdPrompt { return await withCheckedContinuation { promptContinuation = $0 } }
        return prompt
    }
    var calls = 0
    var fails = false
    var writable = 0
    func request(_ selection: HealthAccessSelection) async throws {
        calls += 1
        if fails { throw CocoaError(.userCancelled) }
    }
    func writableCount(_ selection: HealthAccessSelection) -> Int { writable }
}

@MainActor final class HealthDiagnosticTests: XCTestCase {
    func testBackgroundRequestIsRejectedWithoutCallingSystem() async {
        let fake = FakeHealthAuthorizer(); fake.applicationState = "background"
        let service = HealthAuthorizationService(authorizer: fake)
        let result = await service.request(.init(reading: [.body], writing: [.body]))
        XCTAssertFalse(result); XCTAssertEqual(fake.calls, 0)
        XCTAssertEqual(service.failureCode, "ApplicationNotActive")
        XCTAssertEqual(service.diagnostic?.outcome, "notRequested")
        XCTAssertTrue(service.diagnostic?.text.contains("Application: background") == true)
    }
    func testAlreadyRequestedStatusDoesNotClaimReadOrWritePermission() async {
        let fake = FakeHealthAuthorizer(); fake.prompt = .unnecessary; fake.writable = 0
        let service = HealthAuthorizationService(authorizer: fake)
        let result = await service.request(.init(reading: [.body], writing: [.body]))
        XCTAssertTrue(result); XCTAssertEqual(fake.calls, 1)
        XCTAssertEqual(service.state, .processed(writable: 0, requested: 2))
        XCTAssertEqual(service.diagnostic?.promptStatus, .unnecessary)
        XCTAssertEqual(service.diagnostic?.outcome, "processed")
        let text = service.diagnostic?.text ?? ""
        XCTAssertTrue(text.contains("Read authorization is not observable"))
        XCTAssertTrue(text.contains("HKQuantityTypeIdentifierBodyMass"))
        XCTAssertFalse(text.contains("sampleValue")); XCTAssertFalse(text.contains("deviceIdentifier"))
    }
    func testConcurrentRequestWhileCheckingPromptIsNotDuplicated() async {
        let fake = FakeHealthAuthorizer(); fake.holdPrompt = true
        let service = HealthAuthorizationService(authorizer: fake)
        let first = Task { await service.request(.init()) }
        for _ in 0..<100 where fake.promptContinuation == nil { await Task.yield() }
        XCTAssertNotNil(fake.promptContinuation)
        let second = await service.request(.init())
        XCTAssertFalse(second); XCTAssertEqual(service.state, .requesting)
        fake.promptContinuation?.resume(returning: .shouldRequest)
        let result = await first.value
        XCTAssertTrue(result); XCTAssertEqual(fake.calls, 1)
    }
    func testDiagnosticOnlyReportsErrorCodeAndRetryRefreshesIt() async {
        let fake = FakeHealthAuthorizer(); fake.fails = true
        let service = HealthAuthorizationService(authorizer: fake)
        _ = await service.request(.init())
        XCTAssertEqual(service.diagnostic?.outcome, "failed"); XCTAssertNotNil(service.diagnostic?.errorCode)
        fake.fails = false
        _ = await service.request(.init())
        XCTAssertEqual(service.diagnostic?.outcome, "processed"); XCTAssertNil(service.diagnostic?.errorCode)
    }
    func testAutomaticReuseDefaultsOffAndIsRestored() {
        let name = "Leanora.V16.Tests.\(UUID())", defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = AppPreferences(defaults: defaults)
        XCTAssertFalse(preferences.automaticallyReuseWorkoutValues)
        preferences.automaticallyReuseWorkoutValues = true
        XCTAssertTrue(AppPreferences(defaults: defaults).automaticallyReuseWorkoutValues)
    }
}

@MainActor final class FakeNotificationAuthorizer: NotificationAuthorizing {
    var allowed = false
    var fails = false
    var holdStatus = false
    var statusContinuation: CheckedContinuation<NotificationAccess, Never>?
    func status() async -> NotificationAccess {
        if holdStatus {
            return await withCheckedContinuation { statusContinuation = $0 }
        }
        return allowed ? .allowed : .denied
    }
    func request() async throws -> Bool {
        if fails { throw CocoaError(.userCancelled) }
        return allowed
    }
}

@MainActor final class PermissionTests: XCTestCase {
    func testPausedHealthConfigurationRestoresReadingAndWritingSelection() {
        let configuration = HealthSyncConfiguration(enabled: false, reading: [.weight], writing: [.workout, .energy], readActivity: true)
        let selection = HealthAccessSelection(configuration: configuration)
        XCTAssertEqual(selection.reading, [.body, .activity])
        XCTAssertEqual(selection.writing, [.workouts, .nutrition])
        XCTAssertFalse(selection.writing.contains(.activity))
    }
    func testHealthFailureHasActionableDiagnosticAndSuccessfulRetryClearsIt() async {
        let fake = FakeHealthAuthorizer()
        let failing = HealthAuthorizationService(authorizer: fake)
        fake.fails = true
        let result = await failing.request(.init())
        XCTAssertFalse(result); XCTAssertTrue(failing.failureMessage?.contains("取消") == true)
        XCTAssertTrue(failing.failureCode?.contains(NSCocoaErrorDomain) == true)
        fake.fails = false
        let retry = await failing.request(.init())
        XCTAssertTrue(retry); XCTAssertNil(failing.failureCode); XCTAssertNil(failing.failureMessage)
    }
    func testProcessedRequestDoesNotMeanReadPermissionOrAllWritesGranted() async {
        let fake = FakeHealthAuthorizer()
        let service = HealthAuthorizationService(authorizer: fake)
        let selection = HealthAccessSelection(reading: [.body], writing: [.body])
        let result = await service.request(selection)
        XCTAssertTrue(result)
        XCTAssertEqual(service.state, .processed(writable: 0, requested: 2))
        fake.writable = 1
        service.refreshWriteAccess()
        XCTAssertEqual(service.state, .processed(writable: 1, requested: 2))
    }

    func testUnavailableAndEmptySelectionNeverRequestSystemAccess() async {
        let fake = FakeHealthAuthorizer()
        fake.isAvailable = false
        let service = HealthAuthorizationService(authorizer: fake)
        let unavailable = await service.request(.init())
        XCTAssertFalse(unavailable)
        fake.isAvailable = true
        let empty = await service.request(.init(reading: [], writing: []))
        XCTAssertFalse(empty)
        XCTAssertEqual(fake.calls, 0)
    }

    func testHealthRequestFailureCanRetry() async {
        let fake = FakeHealthAuthorizer()
        let service = HealthAuthorizationService(authorizer: fake)
        fake.fails = true
        let failed = await service.request(.init())
        XCTAssertFalse(failed)
        XCTAssertEqual(service.state, .failed)
        fake.fails = false
        let retried = await service.request(.init())
        XCTAssertTrue(retried)
        XCTAssertEqual(fake.calls, 2)
    }

    func testActivityTypesCannotBeRequestedForWriting() {
        let selection = HealthAccessSelection(reading: [.activity], writing: [.activity])
        XCTAssertEqual(selection.readTypes.count, 2)
        XCTAssertTrue(selection.writeTypes.isEmpty)
    }

    func testNotificationDenialAndFailureRemainRecoverable() async {
        let fake = FakeNotificationAuthorizer()
        let service = NotificationPermissionService(authorizer: fake)
        await service.request()
        XCTAssertEqual(service.access, .denied)
        fake.fails = true
        await service.request()
        XCTAssertEqual(service.access, .failed)
        fake.fails = false
        fake.allowed = true
        await service.request()
        XCTAssertEqual(service.access, .allowed)
        XCTAssertFalse(service.isRequesting)
    }

    func testOlderStatusRefreshCannotOverwriteCompletedNotificationRequest() async throws {
        let fake = FakeNotificationAuthorizer()
        fake.holdStatus = true
        fake.allowed = true
        let service = NotificationPermissionService(authorizer: fake)
        let refresh = Task { await service.refresh() }
        for _ in 0..<100 {
            if fake.statusContinuation != nil { break }
            await Task.yield()
        }
        let pendingStatus = try XCTUnwrap(fake.statusContinuation)
        await service.request()
        pendingStatus.resume(returning: .notDetermined)
        await refresh.value
        XCTAssertEqual(service.access, .allowed)
    }
}
