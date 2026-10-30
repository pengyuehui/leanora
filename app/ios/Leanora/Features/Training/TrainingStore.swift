import Foundation
import Observation

extension Exercise: Identifiable { var id: UUID { stamp.id } }
extension WorkoutTemplate: Identifiable { var id: UUID { stamp.id } }
extension WorkoutSession: Identifiable { var id: UUID { stamp.id } }
extension TemplateItem: Identifiable {}

@MainActor @Observable final class TrainingStore {
    let repository: AppModelActor
    let catalog: [Exercise]
    private(set) var exercises: [Exercise] = []
    private(set) var templates: [WorkoutTemplate] = []
    private(set) var sessions: [WorkoutSession] = []
    private(set) var changes: [WorkoutDayChange] = []
    private(set) var busy = false
    var error: String?
    private var refreshGeneration = 0
    private(set) var dataVersion = 0
    private let workoutNotifications = WorkoutNotificationService()
    private(set) var notificationError: String?

    init(repository: AppModelActor, catalog: [Exercise]) { self.repository = repository; self.catalog = catalog }
    var active: WorkoutSession? { sessions.first { [.active, .paused].contains($0.status) } }
    var recentExerciseIDs: [UUID] { WorkoutReuse.recentExerciseIDs(in: sessions) }
    func exercise(_ id: UUID) -> Exercise? { exercises.first { $0.id == id } }
    func occurrences(on date: String) -> [PlannedOccurrence] { TrainingPlan.occurrences(on: date, templates: templates, changes: changes) }
    func isStarted(_ occurrence: PlannedOccurrence) -> Bool {
        sessions.contains { $0.templateID == occurrence.template.id && $0.scheduleOriginDate == occurrence.originDate && $0.status != .abandoned }
    }
    func refresh() async {
        refreshGeneration += 1; let generation = refreshGeneration
        do {
            let records = try await repository.snapshot()
            guard generation == refreshGeneration else { return }
            var values = Dictionary(uniqueKeysWithValues: catalog.map { ($0.stamp.id, $0) })
            for record in records { if case .exercise(let v) = record { values[v.stamp.id] = v } }
            exercises = values.values.filter { $0.stamp.deletedAt == nil }.sorted { $0.name < $1.name }
            templates = records.compactMap { if case .template(let v) = $0, v.stamp.deletedAt == nil { return v }; return nil }.sorted { $0.name < $1.name }
            sessions = records.compactMap { if case .session(let v) = $0, v.stamp.deletedAt == nil { return v }; return nil }
            changes = records.compactMap { if case .schedule(let v) = $0, v.stamp.deletedAt == nil { return v }; return nil }
            dataVersion += 1
            do { try await workoutNotifications.replace(WorkoutNotificationService.reminders(for: active, at: Date())); notificationError = nil }
            catch { notificationError = "系统提醒暂未安排，前台计时仍可使用。" }
        } catch { self.error = error.localizedDescription }
    }
    func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async -> T? {
        guard !busy else { return nil }
        busy = true; error = nil; defer { busy = false }
        do { let result = try await operation(); await refresh(); return result }
        catch { self.error = error.localizedDescription; return nil }
    }
    func start(_ template: WorkoutTemplate, origin: String? = nil) async -> WorkoutSession? {
        await run { [repository, catalog] in try await repository.startTraining(templateID: template.stamp.id, catalog: catalog, originDate: origin) }
    }
    func startFree() async -> WorkoutSession? {
        await run { [repository] in try await repository.startFreeTraining() }
    }
    func repeatWorkout(_ id: UUID) async -> WorkoutSession? {
        await run { [repository, catalog] in try await repository.repeatWorkout(id, catalog: catalog) }
    }
    func setFavorite(_ exercise: Exercise) async {
        _ = await run { [repository, catalog] in try await repository.setExerciseFavorite(exercise.id, favorite: exercise.isFavorite != true, catalog: catalog) }
    }
}
