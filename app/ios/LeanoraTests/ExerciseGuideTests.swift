import XCTest
import ImageIO
import SwiftData
@testable import Leanora

final class ExerciseGuideTests: XCTestCase {
    func testEveryBuiltInExerciseHasDecodableOfflineImagesAndCredits() throws {
        let exercises = try ExerciseCatalog.load(), guides = try ExerciseGuideCatalog.load()
        XCTAssertEqual(Set(exercises.map { $0.stamp.id }), Set(guides.keys))
        var images = Set<String>()
        for exercise in exercises {
            let guide = try XCTUnwrap(guides[exercise.stamp.id])
            XCTAssertFalse(guide.images.isEmpty, exercise.name)
            XCTAssertFalse(guide.credit.isEmpty); XCTAssertFalse(guide.license.isEmpty)
            XCTAssertEqual(URL(string: guide.sourceURL)?.scheme, "https")
            XCTAssertEqual(URL(string: guide.licenseURL)?.scheme, "https")
            for path in guide.images where images.insert(path).inserted {
                let url = try XCTUnwrap(ExerciseGuideCatalog.imageURL(for: path))
                XCTAssertTrue(url.isFileURL)
                let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil), path)
                XCTAssertNotNil(CGImageSourceCreateImageAtIndex(source, 0, nil), path)
            }
        }
        XCTAssertEqual(images.count, 1765)
    }

    func testLegacyIDsAndTypesRemainAvailableWithChineseGuidance() throws {
        let catalog = try ExerciseCatalog.load()
        for number in 1...100 {
            let id = UUID(uuidString: String(format: "10000000-0000-4000-8000-%012d", number))!
            let exercise = try XCTUnwrap(catalog.first { $0.stamp.id == id })
            let guide = try XCTUnwrap(ExerciseGuideCatalog.guide(for: id))
            XCTAssertEqual(exercise.source.reference, "leanora:catalog/exercises/v1")
            XCTAssertFalse(guide.instructions.isEmpty)
        }
        XCTAssertEqual(catalog[6].measurement, .assistedLoad)
        XCTAssertEqual(catalog[17].measurement, .duration)
        XCTAssertEqual(catalog[19].measurement, .cardio)
        let assistedDip = try XCTUnwrap(ExerciseGuideCatalog.guide(for: catalog[31].stamp.id))
        XCTAssertNotNil(assistedDip.variantNote)
        XCTAssertEqual(assistedDip.images, ExerciseGuideCatalog.guide(for: catalog[30].stamp.id)?.images)
    }

    func testExpandedSearchCombinesAliasesEquipmentLevelAndCategory() throws {
        let catalog = try ExerciseCatalog.load()
        let results = ExerciseSearch.filter(catalog, query: "curl", muscle: nil, equipment: "哑铃", level: "初级", category: "力量")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { exercise in
            let guide = ExerciseGuideCatalog.guide(for: exercise.stamp.id)
            return exercise.equipment == "哑铃" && guide?.level == "初级" && guide?.category == "力量"
        })
        XCTAssertFalse(ExerciseSearch.filter(catalog, query: "帕洛夫", muscle: nil, equipment: "绳索器械").isEmpty)
        XCTAssertFalse(ExerciseSearch.filter(catalog, query: "Hamstring Stretch", muscle: nil, equipment: nil, category: "拉伸").isEmpty)
        XCTAssertTrue(ExerciseSearch.filter(catalog, query: "帕洛夫", muscle: nil, equipment: "杠铃").isEmpty)
        let chest = ExerciseSearch.filter(catalog, query: "BENCH", muscle: "胸部", equipment: "杠铃")
        XCTAssertTrue(chest.contains { $0.stamp.id == UUID(uuidString: "10000000-0000-4000-8000-000000000003") })
        XCTAssertNil(ExerciseGuideCatalog.guide(for: UUID()))
    }

    func testMediaPathsCannotEscapeBundledDirectory() {
        for path in ["/etc/passwd", "free/../../secret.jpg", "free/./x.jpg", "free//x.jpg", "https://example.com/x.jpg", "workout/..\\secret.png", "free/a.mp4"] {
            XCTAssertFalse(ExerciseGuideCatalog.validImagePath(path), path)
            XCTAssertNil(ExerciseGuideCatalog.imageURL(for: path))
        }
    }

    func testEquipmentDoesNotTurnBodyweightSupportsIntoExternalLoad() throws {
        let catalog = try ExerciseCatalog.load()
        func entry(_ alias: String) throws -> Exercise {
            try XCTUnwrap(catalog.first { $0.aliases.contains(alias) })
        }
        XCTAssertEqual(try entry("Suspended Row").measurement, .bodyweight)
        XCTAssertEqual(try entry("Band Assisted Pull-Up").measurement, .bodyweight)
        XCTAssertEqual(try entry("Ring Dips").measurement, .bodyweight)
        XCTAssertEqual(try entry("Balance Board").measurement, .duration)
        XCTAssertEqual(try entry("Iron Cross").measurement, .externalLoad)
        XCTAssertEqual(try entry("Suspended Row").equipment, "悬吊带")
    }

    @MainActor func testNewExerciseWorksThroughTemplateWorkoutAndBackupWithoutMediaPayload() async throws {
        let catalog = try ExerciseCatalog.load()
        let imported = try XCTUnwrap(catalog.first { $0.name == "帕洛夫抗旋转推" })
        let actor = AppModelActor(modelContainer: try StoreFactory.memory())
        try await actor.initializeProfile()
        let template = WorkoutTemplate(name: "新增动作训练", items: [TrainingPlan.newItem(for: imported, order: 0)])
        let saved = try await actor.saveTrainingTemplate(template, catalog: catalog)
        let session = try await actor.startTraining(templateID: saved.stamp.id, catalog: catalog)
        XCTAssertEqual(session.exercises.first?.snapshot.exerciseID, imported.stamp.id)
        let export = try await actor.exportBackup()
        let text = try XCTUnwrap(String(data: export.data, encoding: .utf8))
        XCTAssertFalse(text.contains("originalInstructions")); XCTAssertFalse(text.contains("ExerciseMedia"))
        let restored = AppModelActor(modelContainer: try StoreFactory.memory())
        try await restored.initializeProfile()
        let preview = try await restored.prepareImport(export.data)
        _ = try await restored.importBackup(preview, acceptNewer: true)
        let records = try await restored.snapshot()
        XCTAssertEqual(records.filter { $0.kind == "exercise" }.count, 1)
        let workout = try XCTUnwrap(records.compactMap { if case .session(let v) = $0 { return v }; return nil }.first)
        XCTAssertEqual(workout.exercises.first?.snapshot.exerciseID, imported.stamp.id)
        XCTAssertNotNil(ExerciseGuideCatalog.guide(for: imported.stamp.id))
    }
}
