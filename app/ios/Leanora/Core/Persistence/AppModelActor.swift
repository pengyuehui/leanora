import Foundation
import SwiftData

@ModelActor actor AppModelActor {
    #if DEBUG
    private var failNextCommit = false
    func injectCommitFailure() { failNextCommit = true }
    #endif

    func initializeProfile(weightUnit: String = "kg", distanceUnit: String = "km") throws {
        guard try snapshot().isEmpty else { return }
        var profile = LocalProfile(); profile.weightUnit = weightUnit; profile.distanceUnit = distanceUnit
        try save([.profile(profile)])
    }

    func updatePreferences(weight: String, distance: String, days: Int?, energy: Int?) throws {
        let records = try snapshot()
        guard case .profile(var profile) = records.first(where: { $0.kind == "profile" }) else { throw DataProblem.invalid("本机身份") }
        var changes: [BusinessRecord] = []
        if profile.weightUnit != weight || profile.distanceUnit != distance || profile.weeklyTrainingDays != days {
            profile.weightUnit = weight; profile.distanceUnit = distance; profile.weeklyTrainingDays = days
            profile.stamp.revision += 1; profile.stamp.updatedAt = Date(); changes.append(.profile(profile))
        }
        let today = RecordMoment().localDate
        let goals = records.compactMap { record -> NutritionGoal? in
            if case .goal(let v) = record, v.stamp.deletedAt == nil, v.effectiveFrom <= today { return v }; return nil
        }.sorted { $0.effectiveFrom > $1.effectiveFrom }
        let desired = energy.map(Double.init)
        if goals.first?.nutrients.energyKcal != desired {
            if var existing = goals.first, existing.effectiveFrom == today {
                existing.nutrients.energyKcal = desired; existing.stamp.revision += 1; existing.stamp.updatedAt = Date()
                changes.append(.goal(existing))
            } else { changes.append(.goal(NutritionGoal(effectiveFrom: today, nutrients: Nutrients(energyKcal: desired)))) }
        }
        if !changes.isEmpty { try save(changes) }
    }

    func snapshot() throws -> [BusinessRecord] {
        let kind = "business"
        return try modelContext.fetch(FetchDescriptor<StoredRecord>(predicate: #Predicate { $0.kind == kind }))
            .map { row in
                try verify(row)
                let record = try RecordCoding.decode(BusinessRecord.self, from: row.payload)
                guard row.key == "business:\(record.id)" else { throw DataProblem.invalid("存储标识") }
                return record
            }.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func runtimeSnapshot() throws -> [HealthRuntimeRecord] {
        let kind = "runtime"
        return try modelContext.fetch(FetchDescriptor<StoredRecord>(predicate: #Predicate { $0.kind == kind }))
            .map { row in
                try verify(row)
                let record = try RecordCoding.decode(HealthRuntimeRecord.self, from: row.payload)
                guard row.key == record.key else { throw DataProblem.invalid("健康存储标识") }
                return record
            }.sorted { $0.key < $1.key }
    }

    func saveHealthMetadata(links: [HealthSampleLink] = [], suppressions: [HealthSuppression] = []) throws {
        let records = Dictionary(uniqueKeysWithValues: try snapshot().map { ($0.id, $0) })
        for link in links {
            guard let business = records[link.businessID], link.version > 0 else { throw DataProblem.invalid("健康样本映射") }
            _ = try validateComponent(link.component, record: business)
            try DomainValidation.text(link.syncIdentifier, required: true)
            try DomainValidation.text(link.sourceBundleID, required: true)
        }
        for suppression in suppressions {
            try DomainValidation.text(suppression.reason, required: true)
            if let id = suppression.businessID, records[id] == nil { throw DataProblem.invalid("健康抑制引用") }
        }
        try transaction {
            for link in links { try putRuntime(.link(link)) }
            for suppression in suppressions { try putRuntime(.suppression(suppression)) }
        }
    }

    // Explicit aggregate save: no autosave, no HealthKit calls, no suspension
    // between staging business values and jobs and the one SQLite commit.
    func save(_ changes: [BusinessRecord], jobs: [HealthWriteJob] = []) throws {
        let current = try snapshot()
        var merged = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        var changedIDs = Set<UUID>()
        for record in changes {
            guard changedIDs.insert(record.id).inserted else { throw DataProblem.invalid("重复保存 ID") }
            if let old = merged[record.id] {
                guard old.kind == record.kind else { throw DataProblem.invalid("记录类型变化") }
                if try RecordCoding.encode(old) == RecordCoding.encode(record) { continue }
                guard record.stamp.revision == old.stamp.revision + 1,
                      abs(record.stamp.createdAt.timeIntervalSince(old.stamp.createdAt)) < 0.001,
                      record.stamp.updatedAt >= old.stamp.updatedAt else { throw DataProblem.revisionConflict }
            } else if record.stamp.revision != 1 { throw DataProblem.revisionConflict }
            merged[record.id] = record
        }
        try DomainValidation.validate(Array(merged.values))
        let runtime = try runtimeSnapshot()
        if !jobs.isEmpty, runtime.contains(.reconciliationRequired(true)) { throw DataProblem.healthReconciliationRequired }
        for job in jobs {
            guard changedIDs.contains(job.businessID), let record = merged[job.businessID],
                  job.desiredRevision == record.stamp.revision, job.attempts == 0 else {
                throw DataProblem.invalid("健康任务版本")
            }
            let known = try validateComponent(job.component, record: record)
            guard job.action == (known && record.stamp.deletedAt == nil ? .write : .delete) else { throw DataProblem.invalid("健康任务动作") }
        }
        try transaction {
            for record in changes { try put(key: "business:\(record.id)", kind: "business", value: record) }
            let desiredKeys = Set(jobs.map(\.key))
            for item in runtime {
                if case .job(let old) = item, changedIDs.contains(old.businessID), !desiredKeys.contains(old.key),
                   let row = try row(old.key) { modelContext.delete(row) }
            }
            for job in jobs { try putRuntime(.job(job)) }
        }
    }

    // A complete anchored-query page and its next cursor share this commit. A
    // failed batch cannot advance its cursor or leave partial external records.
    func commitHealthImport(_ imported: [HealthRuntimeRecord], deletedSampleIDs: [UUID] = [],
                            cursor: HealthImportCursor) throws {
        guard !cursor.sampleType.isEmpty, cursor.queryEnd == nil || cursor.queryEnd! >= cursor.queryStart,
              cursor.anchor?.count ?? 0 <= 4 * 1024 * 1024 else { throw DataProblem.invalid("健康游标") }
        var keys = Set<String>()
        for item in imported {
            guard keys.insert(item.key).inserted else { throw DataProblem.invalid("重复健康样本") }
            switch item {
            case .workout(let v):
                try DomainValidation.moment(v.started)
                guard v.endedAt >= v.started.instant, !v.sourceBundleID.isEmpty else { throw DataProblem.invalid("外部训练") }
                try DomainValidation.number(v.energyKcal, max: 100_000)
                try DomainValidation.number(v.distanceMeters, max: 10_000_000)
            case .nutrition(let v):
                try DomainValidation.moment(v.occurred)
                guard [.energy, .protein, .carbohydrate, .fat].contains(v.component), !v.sourceBundleID.isEmpty else { throw DataProblem.invalid("外部营养") }
                try DomainValidation.number(v.value, max: 100_000)
            case .body(let v):
                try DomainValidation.moment(v.occurred)
                guard !v.sourceBundleID.isEmpty else { throw DataProblem.invalid("外部测量来源") }
                try DomainValidation.number(v.value, min: 0.000001, max: v.metric == .weightKg ? 1500 : 100)
            default: throw DataProblem.invalid("健康导入类型")
            }
        }
        let existingCursor = try runtimeSnapshot().compactMap { item -> HealthImportCursor? in
            if case .cursor(let v) = item, v.key == cursor.key { return v }; return nil
        }.first
        if let existingCursor, existingCursor.queryStart != cursor.queryStart || existingCursor.queryEnd != cursor.queryEnd {
            throw DataProblem.invalid("健康查询边界变化")
        }
        try transaction {
            for id in deletedSampleIDs { if let row = try row("external:\(id)") { modelContext.delete(row) } }
            for item in imported { try putRuntime(item) }
            try putRuntime(.cursor(cursor))
        }
    }

    func exportBackup() throws -> BackupExport {
        let records = try snapshot()
        try DomainValidation.validate(records)
        guard let profile = records.first(where: { $0.kind == "profile" }) else { throw DataProblem.invalid("本机身份") }
        let data = try RecordCoding.encode(BackupDocument(profileID: profile.id, records: records))
        guard data.count <= BackupService.maximumBytes else { throw DataProblem.tooLarge }
        return BackupExport(data: data, fingerprint: try RecordCoding.fingerprint(records))
    }

    func prepareImport(_ data: Data) throws -> PreparedImport { try BackupService.prepare(data, current: snapshot()) }

    func importBackup(_ preview: PreparedImport, acceptNewer: Bool, replace: Bool = false,
                      exportedFingerprint: String? = nil) throws -> ImportOutcome {
        let current = try snapshot()
        let (records, result) = try BackupService.merge(preview, current: current, acceptNewer: acceptNewer,
                                                       replace: replace, exportedFingerprint: exportedFingerprint)
        // Even identity adoption is a restore boundary. Runtime mappings are never
        // imported, and no write jobs can be enqueued until U7 reconciles Health.
        try transaction {
            let all = try modelContext.fetch(FetchDescriptor<StoredRecord>())
            let keys = Set(records.map { "business:\($0.id)" })
            for row in all where row.kind == "business" && !keys.contains(row.key) { modelContext.delete(row) }
            for row in all where row.kind == "runtime" && (replace || row.key.hasPrefix("job:")) { modelContext.delete(row) }
            for record in records { try put(key: "business:\(record.id)", kind: "business", value: record) }
            try putRuntime(.reconciliationRequired(true))
        }
        return result
    }

    private func validateComponent(_ component: HealthComponent, record: BusinessRecord) throws -> Bool {
        let allowed: [HealthComponent]
        var known = true
        switch record {
        case .session(let v): allowed = [.workout]; known = v.status == .completed
        case .measurement(let v): allowed = [v.metric == .weightKg ? .weight : .bodyFat]
        case .diet(let v):
            allowed = [.energy, .protein, .carbohydrate, .fat]
            switch component {
            case .energy: known = v.nutrients.energyKcal != nil
            case .protein: known = v.nutrients.proteinGrams != nil
            case .carbohydrate: known = v.nutrients.carbohydrateGrams != nil
            case .fat: known = v.nutrients.fatGrams != nil
            default: known = false
            }
        default: allowed = []
        }
        guard allowed.contains(component) else { throw DataProblem.invalid("健康任务组件") }
        return known
    }
    private func row(_ key: String) throws -> StoredRecord? {
        var fetch = FetchDescriptor<StoredRecord>(predicate: #Predicate { $0.key == key })
        fetch.fetchLimit = 1
        return try modelContext.fetch(fetch).first
    }
    private func put<T: Encodable>(key: String, kind: String, value: T) throws {
        let data = try RecordCoding.encode(value)
        if let existing = try row(key) {
            existing.payload = data; existing.contentDigest = RecordCoding.digest(data)
        } else { modelContext.insert(StoredRecord(key: key, kind: kind, payload: data, contentDigest: RecordCoding.digest(data))) }
    }
    private func putRuntime(_ value: HealthRuntimeRecord) throws { try put(key: value.key, kind: "runtime", value: value) }
    private func verify(_ row: StoredRecord) throws {
        if let digest = row.contentDigest, digest != RecordCoding.digest(row.payload) { throw DataProblem.invalid("存储校验") }
    }
    private func transaction(_ changes: () throws -> Void) throws {
        modelContext.autosaveEnabled = false
        do {
            try changes()
            #if DEBUG
            if failNextCommit { failNextCommit = false; throw CocoaError(.fileWriteUnknown) }
            #endif
            try modelContext.save()
        } catch { modelContext.rollback(); throw error }
    }
}
