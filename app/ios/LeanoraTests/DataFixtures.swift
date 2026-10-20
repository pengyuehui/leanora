import Foundation
@testable import Leanora

enum DataFixtures {
    static let date = Date(timeIntervalSince1970: 1_792_483_200)
    static func stamp(_ number: Int) -> RecordStamp {
        RecordStamp(id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", number))!,
                    revision: 1, createdAt: date, updatedAt: date)
    }
    static func records() -> [BusinessRecord] {
        let exercise = Exercise(stamp: stamp(2), name: "自定义推举", equipment: "哑铃", muscles: ["肩"])
        let food = Food(stamp: stamp(5), name: "自定义米饭", nutrientsPer100Grams: Nutrients(energyKcal: 116, proteinGrams: 2.6),
                        units: [FoodUnit(name: "碗", grams: 150)])
        return [
            .profile(LocalProfile(stamp: stamp(1), weightUnit: "kg", distanceUnit: "km", timeZoneID: "Asia/Shanghai", weeklyTrainingDays: 3)),
            .exercise(exercise),
            .template(WorkoutTemplate(stamp: stamp(3), name: "全身训练", items: [TemplateItem(exerciseID: exercise.stamp.id, order: 0)], scheduledWeekdays: [1, 3, 5])),
            .session(WorkoutSession(stamp: stamp(4), started: RecordMoment(date, timeZoneID: "Asia/Shanghai"), endedAt: date.addingTimeInterval(1800), status: .completed,
                                    templateID: stamp(3).id, templateRevision: 1, name: "早间训练", exercises: [
                                        SessionExercise(order: 0, snapshot: ExerciseSnapshot(exercise), sets: [
                                            WorkoutSet(order: 0, loadKg: 20, repetitions: 8, effort: EffortValue(scale: .rir, value: 2), completedAt: date.addingTimeInterval(120))
                                        ])
                                    ])),
            .food(food),
            .diet(DietEntry(stamp: stamp(6), occurred: RecordMoment(date, timeZoneID: "Asia/Shanghai"), meal: .lunch, food: FoodSnapshot(food),
                            quantity: 1, unitName: "碗", grams: 150, nutrients: food.nutrientsPer100Grams.scaled(by: 1.5))),
            .diet(DietEntry(stamp: stamp(7), occurred: RecordMoment(date, timeZoneID: "America/Los_Angeles"), meal: .snack, name: "快速热量", nutrients: Nutrients(energyKcal: 200))),
            .goal(NutritionGoal(stamp: stamp(8), effectiveFrom: "2026-10-19", nutrients: Nutrients(energyKcal: 2000))),
            .goal(NutritionGoal(stamp: stamp(9), effectiveFrom: "2026-10-20", nutrients: Nutrients(energyKcal: 2200))),
            .measurement(BodyMeasurement(stamp: stamp(10), occurred: RecordMoment(date), metric: .weightKg, value: 65)),
            .measurement(BodyMeasurement(stamp: stamp(11), occurred: RecordMoment(date.addingTimeInterval(60)), metric: .weightKg, value: 65.2))
        ]
    }
    static func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("LeanoraTests-\(UUID())", isDirectory: true) }
    static func encoded(_ records: [BusinessRecord]) throws -> Data {
        try RecordCoding.encode(BackupDocument(exportedAt: date, profileID: records.first { $0.kind == "profile" }!.id, records: records))
    }
}
