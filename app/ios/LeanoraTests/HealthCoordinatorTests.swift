#if os(iOS)
import XCTest
@testable import Leanora

@MainActor final class HealthCoordinatorTests: XCTestCase {
    func testConnectingMustAuthorizeBeforeEnablingAndCancelledRequestLeavesConfigurationOff() async throws {
        let repository = try await HealthFixtures.repository()
        try await repository.configureHealth(HealthSyncConfiguration(enabled: false))
        let transport = HealthTestTransport(), fake = FakeHealthAuthorizer()
        let coordinator = HealthSyncCoordinator(repository: repository, transport: transport)
        await coordinator.refresh(); fake.fails = true
        let failed = await coordinator.connect(.init(reading: [.body], writing: [.body]), authorization: HealthAuthorizationService(authorizer: fake))
        XCTAssertFalse(failed); XCTAssertEqual(fake.calls, 1)
        let configuration = try await repository.healthConfiguration(), count = await transport.counts()
        XCTAssertFalse(configuration.enabled); XCTAssertEqual(count.pages, 0); XCTAssertEqual(count.writes, 0)
    }
    func testAuthorizedConnectionRequiresSavedConfigurationAndWritesNewRecord() async throws {
        let repository = try await HealthFixtures.repository()
        try await repository.configureHealth(HealthSyncConfiguration(enabled: false))
        let transport = HealthTestTransport(), fake = FakeHealthAuthorizer()
        let coordinator = HealthSyncCoordinator(repository: repository, transport: transport)
        let service = HealthAuthorizationService(authorizer: fake)
        await coordinator.refresh(); await repository.injectCommitFailure()
        let failed = await coordinator.connect(.init(reading: [.body], writing: [.body]), authorization: service)
        XCTAssertFalse(failed); XCTAssertFalse(coordinator.configuration.enabled); XCTAssertNotNil(coordinator.error)
        let connected = await coordinator.connect(.init(reading: [.body], writing: [.body]), authorization: service)
        XCTAssertTrue(connected); XCTAssertEqual(fake.calls, 2)
        let measurement = BodyMeasurement(metric: .weightKg, value: 65.4)
        try await repository.saveMeasurement(measurement); await coordinator.sync()
        let counts = await transport.counts(); XCTAssertEqual(counts.writes, 1)
        XCTAssertTrue(coordinator.metadata.contains { if case .currentLink(let link) = $0 { return link.businessID == measurement.id && link.state == .written }; return false })
        let stopped = await coordinator.stop(); XCTAssertTrue(stopped)
        XCTAssertEqual(HealthAccessSelection(configuration: coordinator.configuration).writing, [.body])
    }
    func testCleanupStopsIfSyncSettingCannotCommit() async throws {
        let repository = try await HealthFixtures.repository(), transport = HealthTestTransport()
        let sample = HealthFixtures.sample()
        let cursor = HealthImportCursor(installationID: UUID(), sampleType: "weight", queryStart: Date().addingTimeInterval(-60))
        try await repository.commitHealthImport([HealthSampleMapper.projection(sample)], cursor: cursor)
        let coordinator = HealthSyncCoordinator(repository: repository, transport: transport); await coordinator.refresh()
        await repository.injectCommitFailure(); await coordinator.clearCache()
        let count = try await repository.healthCacheCount(), config = try await repository.healthConfiguration()
        XCTAssertEqual(count, 1); XCTAssertTrue(config.enabled); XCTAssertNotNil(coordinator.error)
    }
    func testCleanupSuppressesMappedComponentsBeforeHealthAndRetainsOtherSources() async throws {
        let repository = try await HealthFixtures.repository(), transport = HealthTestTransport()
        let measurement = BodyMeasurement(metric: .weightKg, value: 70); try await repository.saveMeasurement(measurement)
        try await HealthExportService(repository: repository, transport: transport).run()
        await transport.seed([HealthFixtures.sample()])
        let coordinator = HealthSyncCoordinator(repository: repository, transport: transport); await coordinator.refresh(); await coordinator.deleteHealthCopies()
        let samples = await transport.all(); XCTAssertEqual(samples.count, 1); XCTAssertEqual(samples.first?.source, "watch.example")
        let config = try await repository.healthConfiguration(); XCTAssertFalse(config.enabled)
        let suppression = try await repository.healthRuntimeValue("blocked:\(measurement.stamp.id):weight"); XCTAssertNotNil(suppression)
        let local = try await repository.snapshot(); XCTAssertTrue(local.contains { $0.id == measurement.stamp.id })
    }
}
#endif
