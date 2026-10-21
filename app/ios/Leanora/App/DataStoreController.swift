import Foundation
import Observation

@MainActor @Observable final class DataStoreController {
    private(set) var repository: AppModelActor?
    private(set) var training: TrainingStore?
    private(set) var journal: JournalStore?
    private(set) var healthSync: HealthSyncCoordinator?
    private(set) var startupError: String?
    private(set) var preferenceError: String?
    private(set) var recoveries: [URL] = []
    private(set) var isStarting = false
    private var hasAttemptedOpen = false
    private let testing: Bool
    private let reset: Bool

    init(testing: Bool = false, reset: Bool = false) { self.testing = testing; self.reset = reset }

    func start(preferences: AppPreferences) async {
        guard repository == nil, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        startupError = nil
        let testing = testing, reset = reset && !hasAttemptedOpen
        var failOpening = false
        #if DEBUG
        failOpening = testing && !hasAttemptedOpen && ProcessInfo.processInfo.arguments.contains("--store-open-failed")
        #endif
        let shouldFail = failOpening
        hasAttemptedOpen = true
        let weight = preferences.values.weightUnit.rawValue, distance = preferences.values.distanceUnit.rawValue
        let days = preferences.values.weeklyTrainingDays, energy = preferences.values.dailyEnergyGoal
        do {
            let opened = try await Task.detached {
                let directory = try StoreFactory.applicationDirectory(testing: testing)
                if testing && reset && FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.removeItem(at: directory)
                }
                let repository = AppModelActor(modelContainer: try StoreFactory.open(directory: directory, beforeOpen: {
                    if shouldFail { throw CocoaError(.fileReadNoPermission) }
                }))
                if try await repository.snapshot().isEmpty {
                    try await repository.initializeProfile(weightUnit: weight, distanceUnit: distance)
                    try await repository.updatePreferences(weight: weight, distance: distance, days: days, energy: energy)
                }
                try DomainValidation.validate(try await repository.snapshot())
                return repository
            }.value
            try await restorePreferences(from: opened, into: preferences)
            #if DEBUG
            try await UITestBackupFixtures.create(for: opened)
            #endif
            let training = TrainingStore(repository: opened, catalog: try ExerciseCatalog.load())
            await training.refresh()
            self.training = training
            let journal = JournalStore(repository: opened, catalog: try FoodCatalog.load())
            await journal.refresh(); self.journal = journal
            repository = opened
            let sync = HealthSyncCoordinator(repository: opened)
            await sync.refresh(); self.healthSync = sync
            // Discard legacy inert intentions when automatic sync is off.
            await sync.configure(sync.configuration)
            await sync.sync()
        } catch {
            startupError = "本机数据库暂时无法打开。请解锁设备后重试。升级前恢复副本与原库会保留，不会自动清空记录。"
            recoveries = (try? await Task.detached {
                try StoreFactory.recoveryCopies(in: StoreFactory.applicationDirectory(testing: testing))
            }.value) ?? []
        }
    }

    func restore(_ recovery: URL, preferences: AppPreferences) async {
        guard repository == nil, !isStarting else { return }
        isStarting = true
        let testing = testing
        do {
            try await Task.detached {
                try StoreFactory.restoreRecovery(recovery, in: StoreFactory.applicationDirectory(testing: testing))
            }.value
            isStarting = false
            await start(preferences: preferences)
        } catch {
            isStarting = false
            startupError = "恢复暂未完成。当前数据库与恢复副本仍保留，请解锁设备后重试。"
        }
    }

    func restorePreferences(from repository: AppModelActor, into preferences: AppPreferences) async throws {
        let records = try await repository.snapshot()
        if case .profile(let profile) = records.first(where: { $0.kind == "profile" }) {
            let goal = records.compactMap { item -> NutritionGoal? in
                if case .goal(let v) = item, v.stamp.deletedAt == nil, v.effectiveFrom <= RecordMoment().localDate { return v }; return nil
            }.sorted { $0.effectiveFrom > $1.effectiveFrom }.first
            try preferences.save(weight: WeightUnit(rawValue: profile.weightUnit) ?? .kilograms,
                                 distance: DistanceUnit(rawValue: profile.distanceUnit) ?? .kilometers,
                                 days: profile.weeklyTrainingDays,
                                 energyText: goal?.nutrients.energyKcal.map { String(Int($0.rounded())) } ?? "")
        }
    }

    func synchronize(_ values: PreferenceValues) async {
        guard let repository else { return }
        do {
            try await repository.updatePreferences(weight: values.weightUnit.rawValue, distance: values.distanceUnit.rawValue,
                                                   days: values.weeklyTrainingDays, energy: values.dailyEnergyGoal)
            await journal?.refresh()
            preferenceError = nil
        } catch { preferenceError = "单位与目标尚未写入业务数据库，请重试后再导出备份。" }
    }
    func removeLocalRecoveries() async throws {
        let testing = testing
        try await Task.detached {
            let directory = try StoreFactory.applicationDirectory(testing: testing)
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for file in files where file.lastPathComponent == "Recovery" || file.lastPathComponent.hasPrefix("BeforeRestore-") || file.lastPathComponent.hasPrefix("Restore-") {
                try FileManager.default.removeItem(at: file)
            }
        }.value
        recoveries = []
    }
}
