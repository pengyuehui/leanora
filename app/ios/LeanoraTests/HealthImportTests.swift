import XCTest
@testable import Leanora

final class HealthImportTests: XCTestCase, @unchecked Sendable {
    func testThousandSamplesRetryPagesWithoutDuplicatesAndDeletes() async throws {
        let repository = try await HealthFixtures.repository(reading: [.weight]), transport = HealthTestTransport()
        let samples = (0..<1000).map { _ in HealthFixtures.sample() }; await transport.seed(samples); await transport.failPage(500)
        let service = HealthImportService(repository: repository, transport: transport), config = try await repository.healthConfiguration()
        do { try await service.run(configuration: config); XCTFail() } catch {}
        let count = try await repository.healthCacheCount(); XCTAssertEqual(count, 500)
        try await service.run(configuration: config); try await service.run(configuration: config)
        let all = try await repository.healthCacheCount(); XCTAssertEqual(all, 1000)
        await transport.remove(samples[0].id); try await service.run(configuration: config)
        let after = try await repository.healthCacheCount(); XCTAssertEqual(after, 999)
    }
    func testOwnEchoMatchesBusinessButOrphanedOwnSampleIsVisible() async throws {
        let repository = try await HealthFixtures.repository(reading: [.weight]), transport = HealthTestTransport()
        let measurement = BodyMeasurement(metric: .weightKg, value: 70); try await repository.save([.measurement(measurement)])
        let echo = try HealthSampleMapper.export(.measurement(measurement), component: .weight, version: 2, source: transport.sourceBundleID)!
        var orphan = echo; orphan.id = UUID(); orphan.syncIdentifier = HealthSampleMapper.identifier(UUID(), .weight)
        await transport.seed([echo, orphan])
        try await HealthImportService(repository: repository, transport: transport).run(configuration: repository.healthConfiguration())
        let count = try await repository.healthCacheCount(); XCTAssertEqual(count, 1)
        let meta = try await repository.healthMetadata(); XCTAssertTrue(meta.contains { if case .link(let l) = $0 { return l.sampleUUID == echo.id }; return false })
    }
    func testLockedOrDeniedReadPreservesCacheAndFixedRange() async throws {
        let repository = try await HealthFixtures.repository(reading: [.weight]), transport = HealthTestTransport()
        await transport.seed([HealthFixtures.sample()])
        let service = HealthImportService(repository: repository, transport: transport), config = try await repository.healthConfiguration()
        try await service.run(configuration: config)
        await transport.failPage(1); await HealthSyncEngine(repository: repository, transport: transport).run()
        let count = try await repository.healthCacheCount(); XCTAssertEqual(count, 1)
        let meta = try await repository.healthMetadata()
        XCTAssertTrue(meta.contains { if case .check(let c) = $0 { return c.retryNeeded }; return false })
        let cursor = meta.compactMap { if case .cursor(let c) = $0 { return c }; return nil }.first!
        XCTAssertEqual(cursor.queryStart.timeIntervalSince(config.queryStart), 0, accuracy: 0.001)
    }
    func testReauthorizationRescansAndHiddenSampleStaysHidden() async throws {
        let repository = try await HealthFixtures.repository(reading: [.weight]), transport = HealthTestTransport(), sample = HealthFixtures.sample()
        await transport.seed([sample]); let service = HealthImportService(repository: repository, transport: transport)
        try await service.run(configuration: repository.healthConfiguration()); try await repository.hideHealthSample(sample)
        var config = try await repository.healthConfiguration(); config.generation = UUID(); try await repository.configureHealth(config)
        try await service.run(configuration: config)
        let count = try await repository.healthCacheCount(); XCTAssertEqual(count, 0)
    }
    func testEmptyReadDoesNotInferPermissionAndActivityUsesStatistics() async throws {
        let repository = try await HealthFixtures.repository(reading: [.weight]), transport = HealthTestTransport()
        var config = try await repository.healthConfiguration(); config.readActivity = true; try await repository.configureHealth(config)
        await HealthSyncEngine(repository: repository, transport: transport).run()
        let count = try await repository.healthCacheCount(); XCTAssertEqual(count, 0)
        let value = try await repository.healthActivity(day: RecordMoment().localDate, timeZoneID: TimeZone.current.identifier)
        XCTAssertEqual(value?.steps, 123); XCTAssertEqual(value?.activeEnergyKcal, 45)
        XCTAssertNotEqual(RecordMoment.day(Date(timeIntervalSince1970: 0), timeZoneID: "Asia/Shanghai"), RecordMoment.day(Date(timeIntervalSince1970: 0), timeZoneID: "America/Los_Angeles"))
    }
}
