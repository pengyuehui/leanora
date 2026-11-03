import XCTest
@testable import Leanora

final class DietDayCopyTests: XCTestCase, @unchecked Sendable {
    private let zone = "Asia/Shanghai"
    private var source: Date { ISO8601DateFormatter().date(from: "2026-10-30T04:30:00Z")! }
    private var target: Date { ISO8601DateFormatter().date(from: "2026-11-03T01:00:00Z")! }
    private func originals() -> [DietEntry] {
        [DietEntry(occurred: RecordMoment(source, timeZoneID: zone), meal: .lunch, name: "手记", nutrients: Nutrients(energyKcal: 200), notes: "当时记录"),
         DietEntry(occurred: RecordMoment(source.addingTimeInterval(5 * 3600), timeZoneID: zone), meal: .dinner, name: "晚餐", nutrients: Nutrients(energyKcal: 300))]
    }
    func testPreviewPreservesSnapshotAndUnknownsAndSelectsMealsAtOriginalLocalClock() throws {
        let entries = originals()
        let copies = try DietDayCopy.prepare(entries: entries, sourceDay: "2026-10-30", meals: [.lunch], destination: target, timeZoneID: zone)
        XCTAssertEqual(copies.count, 1); XCTAssertNotEqual(copies[0].stamp.id, entries[0].stamp.id)
        XCTAssertEqual(copies[0].nutrients, entries[0].nutrients); XCTAssertNil(copies[0].nutrients.proteinGrams)
        XCTAssertEqual(copies[0].notes, "当时记录"); XCTAssertEqual(copies[0].occurred.localDate, "2026-11-03")
        XCTAssertEqual(copies[0].occurred.instant, ISO8601DateFormatter().date(from: "2026-11-03T04:30:00Z"))
    }
    func testRejectsEmptySameDayInvalidZoneAndOverLimit() throws {
        XCTAssertThrowsError(try DietDayCopy.prepare(entries: originals(), sourceDay: "2026-10-30", meals: [], destination: target, timeZoneID: zone))
        XCTAssertThrowsError(try DietDayCopy.prepare(entries: originals(), sourceDay: "2026-10-30", meals: [.lunch], destination: source, timeZoneID: zone))
        XCTAssertThrowsError(try DietDayCopy.prepare(entries: originals(), sourceDay: "2026-10-30", meals: [.lunch], destination: target, timeZoneID: "invalid"))
        let many = (0..<201).map { _ in originals()[0] }
        XCTAssertThrowsError(try DietDayCopy.prepare(entries: many, sourceDay: "2026-10-30", meals: [.lunch], destination: target, timeZoneID: zone))
    }
    func testDSTMissingClockMovesForwardAndRepeatedClockUsesFirstOccurrence() throws {
        let formatter = ISO8601DateFormatter(), ny = "America/New_York"
        let entry = DietEntry(occurred: RecordMoment(formatter.date(from: "2026-03-07T07:30:00Z")!, timeZoneID: ny), meal: .breakfast, nutrients: Nutrients(energyKcal: 1))
        let copy = try DietDayCopy.prepare(entries: [entry], sourceDay: "2026-03-07", meals: [.breakfast], destination: formatter.date(from: "2026-03-08T16:00:00Z")!, timeZoneID: ny)[0]
        XCTAssertEqual(copy.occurred.localDate, "2026-03-08")
        XCTAssertEqual(copy.occurred.instant, formatter.date(from: "2026-03-08T07:00:00Z"))
        let fall = DietEntry(occurred: RecordMoment(formatter.date(from: "2026-10-31T05:30:00Z")!, timeZoneID: ny), meal: .breakfast, nutrients: Nutrients(energyKcal: 1))
        let repeated = try DietDayCopy.prepare(entries: [fall], sourceDay: "2026-10-31", meals: [.breakfast], destination: formatter.date(from: "2026-11-01T17:00:00Z")!, timeZoneID: ny)[0]
        XCTAssertEqual(repeated.occurred.instant, formatter.date(from: "2026-11-01T05:30:00Z"))
    }
    func testCommitRollbackRetryIdempotencyAndBackupUseRealRepository() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile()
        try await actor.configureHealth(HealthSyncConfiguration(enabled: true, writing: [.energy, .protein, .carbohydrate, .fat]))
        let originals = originals(); try await actor.save(originals.map(BusinessRecord.diet))
        let before = try await actor.snapshot(), runtime = try await actor.runtimeSnapshot()
        let copies = try DietDayCopy.prepare(entries: originals, sourceDay: "2026-10-30", meals: [.lunch,.dinner], destination: target, timeZoneID: zone)
        let preview = try await actor.snapshot(); XCTAssertEqual(preview, before)
        await actor.injectCommitFailure()
        do { try await actor.recordDietDayCopy(copies, catalog: []); XCTFail() } catch {}
        let failed = try await actor.snapshot(), failedRuntime = try await actor.runtimeSnapshot()
        XCTAssertEqual(failed, before); XCTAssertEqual(failedRuntime, runtime)
        try await actor.recordDietDayCopy(copies, catalog: [])
        let first = try await actor.snapshot(), jobs = try await actor.runtimeSnapshot()
        try await actor.recordDietDayCopy(copies, catalog: [])
        let second = try await actor.snapshot(), sameJobs = try await actor.runtimeSnapshot()
        XCTAssertEqual(first, second); XCTAssertEqual(jobs, sameJobs)
        XCTAssertEqual(first.filter { $0.kind == "diet" }.count, 4)
        XCTAssertEqual(jobs.filter { if case .job = $0 { return true }; return false }.count, 2)
        let export = try await actor.exportBackup(), decoded = try BackupService.decode(export.data)
        let decodedCopies = decoded.records.filter { record in copies.contains { $0.stamp.id == record.id } }
        XCTAssertEqual(decodedCopies.count, copies.count)
        for copy in copies {
            XCTAssertEqual(try RecordCoding.encode(decodedCopies.first { $0.id == copy.stamp.id }!), try RecordCoding.encode(BusinessRecord.diet(copy)))
        }
        var edited = copies; edited[0].name = "篡改重试"
        do { try await actor.recordDietDayCopy(edited, catalog: []); XCTFail() } catch { XCTAssertEqual(error as? DataProblem, .revisionConflict) }
    }
    func testPartialReplayAndFoodDependencyMismatchRejectWholeBatch() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile()
        let copies = try DietDayCopy.prepare(entries: originals(), sourceDay: "2026-10-30", meals: [.lunch,.dinner], destination: target, timeZoneID: zone)
        try await actor.recordDietDayCopy([copies[0]], catalog: [])
        let before = try await actor.snapshot()
        do { try await actor.recordDietDayCopy(copies, catalog: []); XCTFail() } catch { XCTAssertEqual(error as? DataProblem, .revisionConflict) }
        let after = try await actor.snapshot(); XCTAssertEqual(before, after)
        let food = Food(name: "米饭", nutrientsPer100Grams: Nutrients(energyKcal: 100))
        let entry = try NutritionCalculator.entry(food: food, quantity: 150, unit: nil, meal: .lunch, at: source, timeZoneID: zone)
        let foodCopy = try DietDayCopy.prepare(entries: [entry], sourceDay: "2026-10-30", meals: [.lunch], destination: target, timeZoneID: zone)
        do { try await actor.recordDietDayCopy(foodCopy, catalog: []); XCTFail() } catch {}
        try await actor.recordDietDayCopy(foodCopy, catalog: [food])
        let saved = try await actor.snapshot()
        XCTAssertEqual(try RecordCoding.encode(saved.first { $0.id == food.stamp.id }!), try RecordCoding.encode(BusinessRecord.food(food)))
        XCTAssertEqual(try RecordCoding.encode(saved.first { $0.id == foodCopy[0].stamp.id }!), try RecordCoding.encode(BusinessRecord.diet(foodCopy[0])))
    }
}
