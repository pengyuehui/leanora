#if DEBUG
import Foundation

enum UITestBackupFixtures {
    static func create(for repository: AppModelActor) async throws {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting"), arguments.contains("--store-screenshots") {
            try await createStoreSamples(for: repository)
            return
        }
        guard arguments.contains("--uitesting"), arguments.contains("--backup-fixtures") else { return }
        let directory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        var records = try await repository.snapshot()
        let stamp = RecordStamp(id: UUID(uuidString: "00000000-0000-4000-8000-000000000999")!, revision: 1,
                                createdAt: Date(timeIntervalSince1970: 1_792_483_200), updatedAt: Date(timeIntervalSince1970: 1_792_483_200))
        records.append(.diet(DietEntry(stamp: stamp, meal: .snack, name: "测试快速记录", nutrients: Nutrients(energyKcal: 200))))
        let profile = records.first { $0.kind == "profile" }!
        try RecordCoding.encode(BackupDocument(profileID: profile.id, records: records))
            .write(to: directory.appendingPathComponent("Leanora-valid.json"), options: .atomic)
        try Data("{invalid-json".utf8).write(to: directory.appendingPathComponent("Leanora-invalid.json"), options: .atomic)
        try StoreFactory.protect(directory)
    }

    // Synthetic records in the isolated UI-test database. No Health data or grants.
    private static func createStoreSamples(for repository: AppModelActor) async throws {
        guard try await repository.snapshot().allSatisfy({ ["profile", "goal"].contains($0.kind) }) else { return }
        let now = Date(), calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let catalog = try ExerciseCatalog.load()
        let exercises = try ["杠铃卧推", "哑铃划船", "哑铃肩推", "哑铃弯举"].map { name in
            guard let exercise = catalog.first(where: { $0.name == name }) else { throw DataProblem.invalid("截图动作目录") }
            return exercise
        }
        let loads: [Double] = [40, 16, 12, 8]
        let items = exercises.enumerated().map { index, exercise in
            TemplateItem(exerciseID: exercise.id, order: index, minimumReps: 8, maximumReps: 12, loadKg: loads[index])
        }
        let template = WorkoutTemplate(name: "上肢力量 A", items: items, scheduledWeekdays: [1, 3, 5], notes: "按自己的节奏，完成每一组。")
        var records = exercises.map(BusinessRecord.exercise) + [.template(template)]
        for (index, offset) in [-6, -4, -2].enumerated() {
            let start = calendar.date(byAdding: .day, value: offset, to: today)!.addingTimeInterval(18 * 3600)
            var session = try TrainingPlan.session(from: template, exercises: exercises, now: start, timeZoneID: TimeZone.current.identifier, originDate: nil)
            session.status = .completed; session.endedAt = start.addingTimeInterval(42 * 60)
            for i in session.exercises.indices {
                for j in session.exercises[i].sets.indices {
                    session.exercises[i].sets[j].loadKg = loads[i] + Double(index)
                    session.exercises[i].sets[j].repetitions = 10
                    session.exercises[i].sets[j].completedAt = start.addingTimeInterval(Double(i * 450 + j * 120 + 60))
                }
            }
            records.append(.session(session))
        }
        let start = now.addingTimeInterval(-18 * 60)
        var current = try TrainingPlan.session(from: template, exercises: exercises, now: start, timeZoneID: TimeZone.current.identifier, originDate: nil)
        for i in current.exercises.indices {
            for j in current.exercises[i].sets.indices {
                current.exercises[i].sets[j].loadKg = loads[i]
                current.exercises[i].sets[j].repetitions = 10
                if i == 0 && j < 2 { current.exercises[i].sets[j].completedAt = start.addingTimeInterval(Double(120 + j * 180)) }
            }
        }
        current.status = .paused
        current.pauses = [PauseInterval(startedAt: start.addingTimeInterval(16 * 60))]
        records.append(.session(current))
        let foods = try FoodCatalog.load()
        let meals: [(String, Double, Meal)] = [("全脂牛奶（添加维生素 D）", 250, .breakfast), ("水煮全蛋", 100, .breakfast), ("香蕉（生）", 120, .breakfast), ("米饭（熟，长粒白米）", 200, .lunch), ("鸡胸肉（去皮，烤熟）", 150, .lunch), ("原味全脂酸奶", 180, .snack)]
        let selectedFoods = try meals.map { name, _, _ in
            guard let food = foods.first(where: { $0.name == name }) else { throw DataProblem.invalid("截图食品目录") }
            return food
        }
        records += selectedFoods.map(BusinessRecord.food)
        let weights: [Double] = [68.2, 68.1, 68.2, 68.0, 68.1, 67.9, 68.0]
        for day in 0..<7 {
            let date = calendar.date(byAdding: .day, value: day - 6, to: today)!
            records.append(.measurement(BodyMeasurement(occurred: RecordMoment(date.addingTimeInterval(8 * 3600)), metric: .weightKg, value: weights[day])))
            for (index, meal) in meals.enumerated() {
                let entry = try NutritionCalculator.entry(food: selectedFoods[index], quantity: meal.1, unit: nil, meal: meal.2,
                                                         at: date.addingTimeInterval(Double(8 + index * 2) * 3600))
                records.append(.diet(entry))
            }
        }
        try await repository.save(records)
        try await repository.updatePreferences(weight: "kg", distance: "km", days: 3, energy: 2200)
    }
}
#endif
