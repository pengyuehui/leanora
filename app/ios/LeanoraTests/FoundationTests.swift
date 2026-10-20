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
    var calls = 0
    var fails = false
    var writable = 0
    func request(_ selection: HealthAccessSelection) async throws {
        calls += 1
        if fails { throw CocoaError(.userCancelled) }
    }
    func writableCount(_ selection: HealthAccessSelection) -> Int { writable }
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
