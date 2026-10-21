import XCTest
@testable import Leanora

final class ReleaseDataTests: XCTestCase, @unchecked Sendable {
    func testCSVPreservesCanonicalUnitsUnknownAndQuotesAndNeutralizesFormulas() throws {
        var records = DataFixtures.records()
        records.append(.diet(DietEntry(meal: .dinner, name: " =HYPERLINK(\"x\")\n午餐,备注", nutrients: Nutrients(energyKcal: 100))))
        let csv = String(decoding: try CSVExportService.encode(records), as: UTF8.self)
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}type,id,parent_id"))
        XCTAssertTrue(csv.contains("' =HYPERLINK(\"\"x\"\")\n午餐,备注"))
        XCTAssertTrue(csv.contains("load_kg")); XCTAssertTrue(csv.contains("body_fat_percent"))
        XCTAssertTrue(csv.contains("\"set\"")); XCTAssertTrue(csv.contains("\"174.0\""))
        XCTAssertEqual(CSVExportService.escape("@SUM(1)"), "\"'@SUM(1)\"")
        XCTAssertTrue(csv.contains("\"200.0\",\"\",\"\",\"\"")) // Unknown macros stay empty.
    }
    func testCacheClearLocalResetAndHealthDeleteAreIndependent() async throws {
        let repository = try await HealthFixtures.repository(reading: [.weight]), transport = HealthTestTransport()
        try await repository.save(DataFixtures.records().filter { $0.kind != "profile" })
        let foreign = HealthFixtures.sample(), own = HealthFixtures.sample(source: transport.sourceBundleID)
        await transport.seed([foreign, own]); try await HealthImportService(repository: repository, transport: transport).run(configuration: repository.healthConfiguration())
        let businessBefore = try await repository.exportBackup()
        try await repository.clearHealthCache()
        let empty = try await repository.healthCacheCount(), backup = try await repository.exportBackup()
        XCTAssertEqual(empty, 0); XCTAssertEqual(backup.fingerprint, businessBefore.fingerprint)
        try await transport.deleteAllOwn(); let health = await transport.all(); XCTAssertEqual(health.map(\.id), [foreign.id])
        try await repository.resetLocalData()
        let local = try await repository.snapshot(); XCTAssertEqual(local.count, 1); XCTAssertEqual(local.first?.kind, "profile")
        let config = try await repository.healthConfiguration(); XCTAssertFalse(config.enabled)
        let remainingHealth = await transport.all(); XCTAssertEqual(remainingHealth.count, 1)
        let after = try await repository.exportBackup(); XCTAssertNotEqual(after.fingerprint, businessBefore.fingerprint)
    }
    func testResetRollbackDoesNotLoseBusinessOrChangeConfiguration() async throws {
        let repository = try await HealthFixtures.repository()
        try await repository.saveMeasurement(BodyMeasurement(metric: .weightKg, value: 60))
        let before = try await repository.exportBackup(), config = try await repository.healthConfiguration()
        await repository.injectCommitFailure()
        do { try await repository.resetLocalData(); XCTFail() } catch {}
        let after = try await repository.exportBackup(), afterConfig = try await repository.healthConfiguration()
        XCTAssertEqual(before.fingerprint, after.fingerprint); XCTAssertEqual(config, afterConfig)
    }
    func testMalformedAndOversizedImportNeverTouchesBusinessOrSyncMetadata() async throws {
        let repository = try await HealthFixtures.repository(), before = try await repository.exportBackup()
        let runtime = try await repository.healthMetadata()
        for bytes in [Data("{\"records\":[]}".utf8), Data(repeating: 65, count: BackupService.maximumBytes + 1)] {
            do { _ = try await repository.prepareImport(bytes); XCTFail() } catch {}
        }
        let after = try await repository.exportBackup(), metadata = try await repository.healthMetadata()
        XCTAssertEqual(after.fingerprint, before.fingerprint); XCTAssertEqual(metadata, runtime)
    }
}
