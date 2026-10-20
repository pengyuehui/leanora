import Foundation

extension AppModelActor {
    func trainingExercises(catalog: [Exercise]) throws -> [Exercise] {
        var result = Dictionary(uniqueKeysWithValues: catalog.map { ($0.stamp.id, $0) })
        for record in try snapshot() { if case .exercise(let v) = record { result[v.stamp.id] = v } }
        return Array(result.values)
    }

    func saveTrainingTemplate(_ draft: WorkoutTemplate, catalog: [Exercise]) throws -> WorkoutTemplate {
        let records = try snapshot()
        var value = draft
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if case .template(let old) = records.first(where: { $0.id == draft.stamp.id }) {
            guard old.stamp.deletedAt == nil, old.stamp.revision == draft.stamp.revision else { throw DataProblem.revisionConflict }
            value.stamp = old.stamp; value.stamp.revision += 1; value.stamp.updatedAt = Date()
        }
        value.items = value.items.enumerated().map { index, item in var item = item; item.order = index; return item }
        let available = try trainingExercises(catalog: catalog)
        let persisted = Set(records.filter { $0.kind == "exercise" }.map(\.id))
        let needed = Set(value.items.map(\.exerciseID)).subtracting(persisted)
        let dependencies = available.filter { needed.contains($0.stamp.id) }.map(BusinessRecord.exercise)
        guard dependencies.count == needed.count else { throw TrainingProblem.missingRecord }
        try save(dependencies + [.template(value)])
        return value
    }

    func copyTrainingTemplate(_ id: UUID) throws -> WorkoutTemplate {
        guard case .template(let original) = try snapshot().first(where: { $0.id == id }), original.stamp.deletedAt == nil else { throw TrainingProblem.missingRecord }
        var copy = original; copy.stamp = RecordStamp(); copy.name += " · 副本"; copy.scheduledWeekdays = []
        var pairs: [UUID: UUID] = [:]
        copy.items = original.items.map { old in
            var item = old; item.id = UUID()
            if let pair = old.supersetID { if pairs[pair] == nil { pairs[pair] = UUID() }; item.supersetID = pairs[pair] }
            return item
        }
        try save([.template(copy)])
        return copy
    }

    func deleteTrainingTemplate(_ template: WorkoutTemplate) throws {
        guard case .template(var current) = try snapshot().first(where: { $0.id == template.stamp.id }), current.stamp.revision == template.stamp.revision else { throw DataProblem.revisionConflict }
        current.stamp.revision += 1; current.stamp.updatedAt = Date(); current.stamp.deletedAt = Date()
        try save([.template(current)])
    }

    func saveCustomExercise(_ draft: Exercise, catalog: [Exercise]) throws {
        guard !catalog.contains(where: { $0.stamp.id == draft.stamp.id }) else { throw DataProblem.invalid("基础动作不可直接改写") }
        var value = draft; value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if case .exercise(let old) = try snapshot().first(where: { $0.id == value.stamp.id }) {
            guard old.stamp.revision == value.stamp.revision, old.stamp.deletedAt == nil else { throw DataProblem.revisionConflict }
            value.stamp = old.stamp; value.stamp.revision += 1; value.stamp.updatedAt = Date()
        }
        value.source = ContentSource()
        try save([.exercise(value)])
    }

    func setExerciseArchived(_ id: UUID, archived: Bool, catalog: [Exercise]) throws {
        guard var value = try trainingExercises(catalog: catalog).first(where: { $0.stamp.id == id }), value.stamp.deletedAt == nil else { throw TrainingProblem.missingRecord }
        let persisted = try snapshot().contains { $0.id == id }
        value.isArchived = archived
        if persisted { value.stamp.revision += 1; value.stamp.updatedAt = Date() }
        try save([.exercise(value)])
    }

    func rescheduleTraining(templateID: UUID, originDate: String, destinationDate: String, timeZoneID: String) throws {
        try DomainValidation.day(originDate); try DomainValidation.day(destinationDate)
        let records = try snapshot()
        guard case .template(let template) = records.first(where: { $0.id == templateID }), template.stamp.deletedAt == nil else { throw TrainingProblem.missingRecord }
        if records.contains(where: {
            if case .session(let s) = $0 { return s.stamp.deletedAt == nil && s.templateID == templateID && s.scheduleOriginDate == originDate && s.status != .abandoned }; return false
        }) { throw TrainingProblem.startedOccurrence }
        let previous = records.compactMap { record -> WorkoutDayChange? in
            if case .schedule(let v) = record, v.templateID == templateID, v.originDate == originDate, v.stamp.deletedAt == nil { return v }; return nil
        }.first
        guard previous != nil || template.scheduledWeekdays.contains(TrainingPlan.weekday(originDate)) else { throw TrainingProblem.missingRecord }
        var change = previous ?? WorkoutDayChange(templateID: templateID, originDate: originDate, destinationDate: destinationDate, timeZoneID: timeZoneID)
        change.destinationDate = destinationDate; change.timeZoneID = timeZoneID
        if previous != nil { change.stamp.revision += 1; change.stamp.updatedAt = Date() }
        try save([.schedule(change)])
    }

    func startTraining(templateID: UUID, catalog: [Exercise], originDate: String? = nil, now: Date = Date(), timeZoneID: String = TimeZone.current.identifier) throws -> WorkoutSession {
        let records = try snapshot()
        let sessions = records.compactMap { record -> WorkoutSession? in if case .session(let v) = record, v.stamp.deletedAt == nil { return v }; return nil }
        if let active = sessions.first(where: { [.active, .paused].contains($0.status) }) { return active }
        guard case .template(let template) = records.first(where: { $0.id == templateID }), template.stamp.deletedAt == nil else { throw TrainingProblem.missingRecord }
        if let originDate {
            let changes = records.compactMap { record -> WorkoutDayChange? in if case .schedule(let v) = record { return v }; return nil }
            guard TrainingPlan.occurrences(on: RecordMoment(now, timeZoneID: timeZoneID).localDate, templates: [template], changes: changes).contains(where: { $0.originDate == originDate }) else { throw TrainingProblem.missingRecord }
            if sessions.contains(where: { $0.templateID == templateID && $0.scheduleOriginDate == originDate && $0.status != .abandoned }) { throw TrainingProblem.alreadyStarted }
        }
        let required = try TrainingPlan.requiredSessionRecords(template)
        guard records.reduce(0, { $0 + 1 + $1.nestedIDs.count }) + required <= DomainValidation.maximumRecords else { throw DataProblem.tooManyRecords }
        let session = try TrainingPlan.session(from: template, exercises: trainingExercises(catalog: catalog), now: now, timeZoneID: timeZoneID, originDate: originDate)
        try save([.session(session)])
        return session
    }

    func abandonTraining(_ id: UUID) throws {
        guard case .session(var value) = try snapshot().first(where: { $0.id == id }), [.active, .paused].contains(value.status) else { throw TrainingProblem.missingRecord }
        let now = max(Date(), max(value.started.instant, value.stamp.updatedAt))
        if value.pauses.last?.endedAt == nil && !value.pauses.isEmpty { value.pauses[value.pauses.count - 1].endedAt = now }
        value.status = .abandoned; value.endedAt = now; value.stamp.revision += 1; value.stamp.updatedAt = now
        try save([.session(value)])
    }
}
