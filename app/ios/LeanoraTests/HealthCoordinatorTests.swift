#if os(iOS)
import XCTest
@testable import Leanora

@MainActor final class HealthCoordinatorTests: XCTestCase {
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
