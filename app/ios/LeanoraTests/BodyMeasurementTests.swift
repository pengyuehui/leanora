import XCTest
@testable import Leanora

final class BodyMeasurementTests: XCTestCase, @unchecked Sendable {
    func testMultipleSameDayMeasurementsRetainedAndDailyLatestUsedForAverage() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile()
        let now = Date(); let early = BodyMeasurement(occurred: RecordMoment(now.addingTimeInterval(-60)), metric: .weightKg, value: 60)
        let late = BodyMeasurement(occurred: RecordMoment(now), metric: .weightKg, value: 62)
        try await actor.saveMeasurement(early); try await actor.saveMeasurement(late)
        let values = try await actor.snapshot().compactMap { if case .measurement(let v) = $0 { return v }; return nil }
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(BodySummary.dailyLatest(values, metric: .weightKg).last?.stamp.id, late.stamp.id)
        XCTAssertEqual(BodySummary.average(values, metric: .weightKg, from: late.occurred.localDate, through: late.occurred.localDate), 62)
    }
    func testPercentBoundaryWeightUnitConversionAndInvalidInput() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile()
        let weight = BodyMeasurement(metric: .weightKg, value: 150 * 0.45359237)
        try await actor.saveMeasurement(weight)
        let fat = BodyMeasurement(metric: .bodyFatPercent, value: 20)
        try await actor.saveMeasurement(fat)
        for number in [0.0, -1, 101, .infinity] {
            do { try await actor.saveMeasurement(BodyMeasurement(metric: .bodyFatPercent, value: number)); XCTFail() } catch {}
        }
        let records = try await actor.snapshot(); XCTAssertEqual(records.filter { $0.kind == "measurement" }.count, 2)
    }
    func testEditDeleteAndBackupRoundTrip() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile()
        var value = BodyMeasurement(metric: .bodyFatPercent, value: 20); try await actor.saveMeasurement(value)
        value.value = 21; try await actor.saveMeasurement(value)
        try await actor.deleteMeasurement(value.stamp.id, revision: 2)
        let backup = try await actor.exportBackup(); let prepared = try BackupService.prepare(backup.data, current: [])
        XCTAssertTrue(prepared.document.records.contains { if case .measurement(let v) = $0 { return v.value == 21 && v.stamp.deletedAt != nil }; return false })
    }
}
