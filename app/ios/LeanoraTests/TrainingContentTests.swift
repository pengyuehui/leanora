import XCTest
@testable import Leanora

final class TrainingContentTests: XCTestCase, @unchecked Sendable {
    func testBundledOriginalContentHasFourProgramsNineTemplatesAndEightGuides() throws {
        let content = try TrainingContentCatalog.load(), catalog = try ExerciseCatalog.load()
        XCTAssertEqual(content.programs.count, 4); XCTAssertEqual(content.programs.flatMap(\.templates).count, 9)
        XCTAssertEqual(content.guides.count, 8); XCTAssertEqual(content.license, "MIT")
        for program in content.programs {
            let templates = try content.makeTemplates(programID: program.id, exercises: catalog)
            XCTAssertEqual(templates.count, program.templates.count)
            XCTAssertTrue(templates.allSatisfy { $0.scheduledWeekdays.isEmpty })
            XCTAssertTrue(templates.flatMap(\.items).allSatisfy { $0.loadKg == nil && $0.plannedSets == 2 })
            for item in templates.flatMap(\.items) { XCTAssertNotNil(ExerciseGuideCatalog.guide(for: item.exerciseID)) }
        }
    }
    func testAdoptionIsExplicitAtomicAndRepeatDoesNotOverwriteExistingTemplates() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile()
        let catalog = try ExerciseCatalog.load(), content = try TrainingContentCatalog.load()
        _ = try content.makeTemplates(programID: "full-body", exercises: catalog)
        let before = try await actor.snapshot(); XCTAssertEqual(before.count, 1)
        let first = try await actor.adoptTrainingProgram("full-body", catalog: catalog)
        let again = try await actor.adoptTrainingProgram("full-body", catalog: catalog)
        XCTAssertEqual(first.count, 2); XCTAssertEqual(again.count, 2)
        XCTAssertTrue(Set(first.map { $0.stamp.id }).isDisjoint(with: again.map { $0.stamp.id }))
        XCTAssertEqual(Set((first + again).map(\.name)).count, 4)
        let records = try await actor.snapshot()
        XCTAssertEqual(records.filter { $0.kind == "template" }.count, 4)
        XCTAssertTrue(first.allSatisfy { $0.scheduledWeekdays.isEmpty })
        let session = try await actor.startTraining(templateID: first[0].stamp.id, catalog: catalog)
        XCTAssertEqual(session.exercises.count, first[0].items.count)
        XCTAssertTrue(session.exercises.flatMap(\.sets).allSatisfy { $0.completedAt == nil && $0.loadKg == nil })
    }
    func testProgramAdoptionFailureDoesNotLeaveTemplatesOrCatalogDependencies() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile()
        let before = try await actor.snapshot(), catalog = try ExerciseCatalog.load()
        await actor.injectCommitFailure()
        do { _ = try await actor.adoptTrainingProgram("full-body", catalog: catalog); XCTFail() } catch {}
        let after = try await actor.snapshot(); XCTAssertEqual(before, after)
    }
    func testProgramRejectsArchivedMissingAndChangedMeasurementWithoutWrites() async throws {
        let actor = AppModelActor(modelContainer: try StoreFactory.memory()); try await actor.initializeProfile()
        var catalog = try ExerciseCatalog.load()
        let id = try TrainingContentCatalog.load().programs[0].templates[0].items[0].exerciseID
        let index = catalog.firstIndex { $0.stamp.id == id }!
        catalog[index].isArchived = true
        do { _ = try await actor.adoptTrainingProgram("full-body", catalog: catalog); XCTFail() }
        catch { XCTAssertEqual(error as? TrainingProblem, .archivedExercise) }
        catalog[index].isArchived = false; catalog[index].measurement = .duration
        do { _ = try await actor.adoptTrainingProgram("full-body", catalog: catalog); XCTFail() } catch {}
        let records = try await actor.snapshot(); XCTAssertEqual(records.count, 1)
        XCTAssertThrowsError(try TrainingContentCatalog.load().makeTemplates(programID: "missing", exercises: catalog))
    }
    func testMalformedDuplicateAndMissingReferencesAreRejected() throws {
        let catalog = try ExerciseCatalog.load()
        let fixture: [String: Any] = ["version":1,"author":"Leanora","license":"MIT",
            "programs":[["id":"p","title":"示例","subtitle":"说明","equipment":"自重","summary":"原始说明",
                         "templates":[["id":"t","title":"训练日","items":[["exerciseID":catalog[0].stamp.id.uuidString,"sets":2,"minimumReps":8,"maximumReps":12,"restSeconds":90]]]]]],
            "guides":[["id":"g","title":"指南","summary":"说明","sections":[["title":"正文","paragraphs":["原创正文"]]]]]]
        XCTAssertNoThrow(try TrainingContentCatalog.decode(JSONSerialization.data(withJSONObject: fixture), exercises: catalog))
        var invalid = fixture; invalid["version"] = 99
        XCTAssertThrowsError(try TrainingContentCatalog.decode(JSONSerialization.data(withJSONObject: invalid), exercises: catalog))
        invalid = fixture
        var guides = invalid["guides"] as! [[String: Any]]; guides[0]["id"] = "p"; invalid["guides"] = guides
        XCTAssertThrowsError(try TrainingContentCatalog.decode(JSONSerialization.data(withJSONObject: invalid), exercises: catalog))
        XCTAssertThrowsError(try TrainingContentCatalog.decode(JSONSerialization.data(withJSONObject: fixture), exercises: []))
    }
}
