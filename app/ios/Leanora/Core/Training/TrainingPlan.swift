import Foundation

enum TrainingProblem: Error, LocalizedError, Equatable {
    case emptyTemplate, archivedExercise, missingRecord, alreadyStarted, invalidTargets, startedOccurrence
    var errorDescription: String? {
        switch self {
        case .emptyTemplate: "请先为模板添加动作，再开始训练。"
        case .archivedExercise: "模板包含已归档的动作，请先替换或恢复该动作。"
        case .missingRecord: "资料已更改或移除，请刷新后重试。"
        case .alreadyStarted: "该次安排已有训练记录，请返回查看。"
        case .invalidTargets: "计划目标格式不正确，请输入有效数字。"
        case .startedOccurrence: "这次安排已经开始，不能再改期。"
        }
    }
}

struct PlannedOccurrence: Identifiable, Equatable, Sendable {
    var template: WorkoutTemplate
    var originDate: String
    var date: String
    var id: String { "\(template.stamp.id):\(originDate)" }
    var isMoved: Bool { originDate != date }
}

enum TrainingPlan {
    static func weekday(_ date: String) -> Int {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt; formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: date) else { return 0 }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .gmt
        return (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    static func occurrences(on date: String, templates: [WorkoutTemplate], changes: [WorkoutDayChange]) -> [PlannedOccurrence] {
        var result: [String: PlannedOccurrence] = [:]
        for template in templates where template.stamp.deletedAt == nil {
            if template.scheduledWeekdays.contains(weekday(date)),
               !changes.contains(where: { $0.stamp.deletedAt == nil && $0.templateID == template.stamp.id && $0.originDate == date && $0.destinationDate != date }) {
                let occurrence = PlannedOccurrence(template: template, originDate: date, date: date)
                result[occurrence.id] = occurrence
            }
            for change in changes where change.stamp.deletedAt == nil && change.templateID == template.stamp.id && change.destinationDate == date {
                let occurrence = PlannedOccurrence(template: template, originDate: change.originDate, date: date)
                result[occurrence.id] = occurrence
            }
        }
        return result.values.sorted { $0.id < $1.id }
    }

    static func newItem(for exercise: Exercise, order: Int) -> TemplateItem {
        var item = TemplateItem(exerciseID: exercise.stamp.id, order: order)
        switch exercise.measurement {
        case .externalLoad, .bodyweight, .assistedLoad: item.minimumReps = 8; item.maximumReps = 12
        case .duration: item.durationSeconds = 60
        case .cardio: item.plannedSets = 1; item.durationSeconds = 600
        }
        return item
    }

    static func session(from template: WorkoutTemplate, exercises: [Exercise], now: Date, timeZoneID: String, originDate: String?) throws -> WorkoutSession {
        guard !template.items.isEmpty else { throw TrainingProblem.emptyTemplate }
        _ = try requiredSessionRecords(template)
        let lookup = Dictionary(uniqueKeysWithValues: exercises.map { ($0.stamp.id, $0) })
        let values = try template.items.sorted { $0.order < $1.order }.enumerated().map { index, item in
            guard let exercise = lookup[item.exerciseID], exercise.stamp.deletedAt == nil else { throw TrainingProblem.missingRecord }
            guard !exercise.isArchived else { throw TrainingProblem.archivedExercise }
            return SessionExercise(order: index, snapshot: ExerciseSnapshot(exercise),
                                   sets: (0..<item.plannedSets).map { WorkoutSet(order: $0) }, supersetID: item.supersetID,
                                   templateItemID: item.id,
                                   plannedTargets: PlannedTargets(sets: item.plannedSets, minimumReps: item.minimumReps, maximumReps: item.maximumReps,
                                                                  loadKg: item.loadKg, durationSeconds: item.durationSeconds,
                                                                  distanceMeters: item.distanceMeters, restSeconds: item.restSeconds))
        }
        return WorkoutSession(started: RecordMoment(now, timeZoneID: timeZoneID), status: .active,
                              templateID: template.stamp.id, templateRevision: template.stamp.revision,
                              name: template.name, exercises: values, notes: template.notes, scheduleOriginDate: originDate)
    }

    static func requiredSessionRecords(_ template: WorkoutTemplate) throws -> Int {
        var count = 1
        for item in template.items {
            guard (1...1000).contains(item.plannedSets) else { throw TrainingProblem.invalidTargets }
            count += 1 + item.plannedSets
            guard count <= DomainValidation.maximumRecords else { throw DataProblem.tooManyRecords }
        }
        return count
    }
}
