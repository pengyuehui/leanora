import XCTest
@testable import Leanora

final class MealTemplateTests: XCTestCase, @unchecked Sendable {
    private func fixture() throws -> (Food, MealTemplate) {
        let food = Food(name: "米饭", nutrientsPer100Grams: Nutrients(energyKcal: 130, proteinGrams: 2, carbohydrateGrams: 28, fatGrams: 0.3))
        let entry = try NutritionCalculator.entry(food: food, quantity: 150, unit: nil, meal: .lunch, at: DataFixtures.date)
        let quick = DietEntry(meal: .lunch, name: "酱汁", nutrients: Nutrients(energyKcal: 30))
        return (food, try MealTemplate.draft(name: "我的午餐", entries: [entry, entry, quick]))
    }
    func testServingsPreserveUnknownsAndCreateIndependentRecords() throws {
        let (_, template) = try fixture()
        let half = try template.entries(servings: 0.5, meal: .dinner, date: DataFixtures.date)
        XCTAssertEqual(half.count, 3); XCTAssertEqual(Set(half.map { $0.stamp.id }).count, 3)
        XCTAssertEqual(half[0].grams, 75); XCTAssertEqual(half[0].nutrients.energyKcal, 97.5)
        XCTAssertEqual(half[2].nutrients.energyKcal, 15); XCTAssertNil(half[2].nutrients.proteinGrams)
        XCTAssertEqual(half[0].meal, .dinner)
        XCTAssertEqual(template.items[0].grams, 150)
        let two = try template.entries(servings: 2, meal: .lunch, date: DataFixtures.date)
        XCTAssertEqual(two[0].nutrients.energyKcal, 390)
        let copy = template.copied(); XCTAssertNotEqual(copy.id, template.id)
        XCTAssertTrue(Set(copy.items.map(\.id)).isDisjoint(with: template.items.map(\.id)))
    }
    func testInvalidServingsTamperedNutritionAndEmptyCombinationRejected() throws {
        let (_, template) = try fixture()
        for value in [0.0, -1, .infinity, .nan, 101] {
            XCTAssertThrowsError(try template.entries(servings: value, meal: .lunch, date: Date()))
        }
        XCTAssertThrowsError(try MealTemplate.draft(name: "空", entries: []))
        var bad = template; bad.items[0].nutrients.energyKcal = 1
        XCTAssertThrowsError(try bad.validate())
    }
    func testAtomicBatchAndHealthJobsRollbackAndRetryAreIdempotent() async throws {
        let (food, template) = try fixture()
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile()
        try await actor.configureHealth(HealthSyncConfiguration(enabled: true, writing: [.energy,.protein]))
        _ = try await actor.saveMealTemplate(template, catalog: [food])
        let before = try await actor.exportBackup()
        let entries = try template.entries(servings: 0.5, meal: .lunch, date: Date())
        await actor.injectCommitFailure()
        do { try await actor.recordMeal(entries, catalog: [food]); XCTFail() } catch {}
        let after = try await actor.exportBackup(); XCTAssertEqual(after.fingerprint, before.fingerprint)
        var runtime = try await actor.runtimeSnapshot(); XCTAssertFalse(runtime.contains { if case .job = $0 { return true }; return false })
        try await actor.recordMeal(entries, catalog: [food]); try await actor.recordMeal(entries, catalog: [food])
        let records = try await actor.snapshot(); XCTAssertEqual(records.filter { $0.kind == "diet" }.count, 3)
        runtime = try await actor.runtimeSnapshot(); XCTAssertEqual(runtime.filter { if case .job = $0 { return true }; return false }.count, 5)
    }
    func testSavedMealRoundTripLegacyBackupAndRevisionProtection() async throws {
        let (food, template) = try fixture()
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile()
        let saved = try await actor.saveMealTemplate(template, catalog: [food])
        var changed = saved; changed.name = "修改组合"
        let edited = try await actor.saveMealTemplate(changed, catalog: [food]); XCTAssertEqual(edited.stamp.revision, 2)
        do { _ = try await actor.saveMealTemplate(changed, catalog: [food]); XCTFail() } catch { XCTAssertEqual(error as? DataProblem, .revisionConflict) }
        let export = try await actor.exportBackup(); var document = try BackupService.decode(export.data)
        XCTAssertEqual(document.version, 2)
        XCTAssertEqual(try RecordCoding.encode(document.records.first { $0.id == edited.id }), try RecordCoding.encode(Optional(BusinessRecord.mealTemplate(edited))))
        document.version = 1; XCTAssertThrowsError(try BackupService.decode(RecordCoding.encode(document)))
        var old = BackupDocument(profileID: DataFixtures.stamp(1).id, records: DataFixtures.records()); old.version = 1
        XCTAssertEqual(try BackupService.decode(RecordCoding.encode(old)).version, 1)
        let target = AppModelActor(modelContainer: try StoreFactory.memory()); try await target.initializeProfile()
        let preview = try await target.prepareImport(export.data); _ = try await target.importBackup(preview, acceptNewer: true)
        let restored = try await target.snapshot()
        XCTAssertEqual(try RecordCoding.encode(restored.first { $0.id == edited.id }), try RecordCoding.encode(Optional(BusinessRecord.mealTemplate(edited))))
        let runtime = try await target.runtimeSnapshot(); XCTAssertTrue(runtime.contains(.reconciliationRequired(true)))
    }
    func testHistoryDraftAndDeletionNeverChangeHistoricalEntries() async throws {
        let (food, template) = try fixture()
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile()
        let entries = try template.entries(servings: 1, meal: .lunch, date: DataFixtures.date)
        try await actor.recordMeal(entries, catalog: [food])
        let before = try await actor.exportBackup()
        let draft = try await actor.mealDraft(from: entries[0].occurred.localDate, meal: .lunch)
        let previewOnly = try await actor.exportBackup(); XCTAssertEqual(before.fingerprint, previewOnly.fingerprint)
        let saved = try await actor.saveMealTemplate(draft, catalog: [food]); try await actor.deleteMealTemplate(saved)
        let records = try await actor.snapshot()
        for entry in entries {
            guard case .diet(let stored) = records.first(where: { $0.id == entry.stamp.id }) else { return XCTFail() }
            XCTAssertEqual(try RecordCoding.encode(stored), try RecordCoding.encode(entry))
        }
    }
    func testDiskReopenKeepsCombinationFavoritesAndFoodSnapshots() async throws {
        let directory = DataFixtures.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (food, template) = try fixture()
        do {
            let actor = AppModelActor(modelContainer: try StoreFactory.open(directory: directory)); try await actor.initializeProfile()
            _ = try await actor.saveMealTemplate(template, catalog: [food])
            try await actor.setFoodFavorite(food.stamp.id, favorite: true, catalog: [food])
        }
        let reopened = AppModelActor(modelContainer: try StoreFactory.open(directory: directory))
        let records = try await reopened.snapshot()
        guard case .mealTemplate(let saved) = records.first(where: { $0.id == template.id }) else { return XCTFail() }
        XCTAssertEqual(saved.items, template.items)
        guard case .food(var stored) = records.first(where: { $0.id == food.stamp.id }) else { return XCTFail() }
        XCTAssertEqual(stored.isFavorite, true)
        stored.isArchived = true; try await reopened.saveCustomFood(stored, catalog: [])
        let entry = try saved.entries(servings: 1, meal: .lunch, date: Date())
        try await reopened.recordMeal(entry, catalog: [])
        let latest = try await reopened.snapshot(); XCTAssertEqual(latest.filter { $0.kind == "diet" }.count, 3)
        XCTAssertEqual(entry[0].food?.name, food.name)
    }
    func testDuplicateIDsTooManyItemsOverflowAndPartialReplayAreRejected() async throws {
        let (food, template) = try fixture()
        var bad = template; bad.items[1].id = bad.items[0].id
        XCTAssertThrowsError(try bad.validate())
        bad = template; bad.items = (0..<51).map { index in var item = template.items[0]; item.id = UUID(); item.order = index; return item }
        XCTAssertThrowsError(try bad.validate())
        let huge = try NutritionCalculator.entry(food: food, quantity: 50_000, unit: nil, meal: .lunch, at: Date())
        let oversized = try MealTemplate.draft(name: "超范围", entries: [huge])
        XCTAssertThrowsError(try oversized.entries(servings: 2, meal: .lunch, date: Date()))
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile()
        let entries = try template.entries(servings: 1, meal: .lunch, date: Date())
        try await actor.recordMeal([entries[0]], catalog: [food])
        do { try await actor.recordMeal(entries, catalog: [food]); XCTFail() } catch { XCTAssertEqual(error as? DataProblem, .revisionConflict) }
        let records = try await actor.snapshot(); XCTAssertEqual(records.filter { $0.kind == "diet" }.count, 1)
    }
}
