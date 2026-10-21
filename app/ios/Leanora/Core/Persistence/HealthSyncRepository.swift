import Foundation
import SwiftData

struct HealthDashboardSnapshot: Sendable {
    var configuration: HealthSyncConfiguration
    var metadata: [HealthRuntimeRecord]
    var cache: [HealthRuntimeRecord]
    var count: Int
    var activity: HealthDailyActivity?
}

extension AppModelActor {
    func healthDashboard(day: String, timeZoneID: String) throws -> HealthDashboardSnapshot {
        HealthDashboardSnapshot(configuration: try healthConfiguration(), metadata: try healthMetadata(), cache: try healthCachePage(), count: try healthCacheCount(), activity: try healthActivity(day: day, timeZoneID: timeZoneID))
    }
    func healthRuntimeValue(_ key: String) throws -> HealthRuntimeRecord? {
        guard let row = try row(key) else { return nil }
        try verify(row)
        return try RecordCoding.decode(HealthRuntimeRecord.self, from: row.payload)
    }

    // Import pages do not decode the growing sample cache. Metadata stays small;
    // UI reads an explicit bounded page of external summaries.
    func healthMetadata() throws -> [HealthRuntimeRecord] {
        let kind = "runtime", prefix = "external:", activity = "activity:"
        return try modelContext.fetch(FetchDescriptor<StoredRecord>(predicate: #Predicate {
            $0.kind == kind && !$0.key.starts(with: prefix) && !$0.key.starts(with: activity)
        })).map { try verify($0); return try RecordCoding.decode(HealthRuntimeRecord.self, from: $0.payload) }
    }
    func healthCachePage(offset: Int = 0, limit: Int = 100) throws -> [HealthRuntimeRecord] {
        let prefix = "external:"
        var fetch = FetchDescriptor<StoredRecord>(predicate: #Predicate { $0.key.starts(with: prefix) }, sortBy: [SortDescriptor(\.key)])
        fetch.fetchOffset = max(0, offset); fetch.fetchLimit = min(max(1, limit), 1000)
        return try modelContext.fetch(fetch).map { try verify($0); return try RecordCoding.decode(HealthRuntimeRecord.self, from: $0.payload) }
    }
    func healthCacheCount() throws -> Int {
        let prefix = "external:"
        return try modelContext.fetchCount(FetchDescriptor<StoredRecord>(predicate: #Predicate { $0.key.starts(with: prefix) }))
    }
    func healthConfiguration() throws -> HealthSyncConfiguration {
        if case .configuration(let value) = try healthRuntimeValue("health:configuration") { return value }
        return HealthSyncConfiguration()
    }
    func configureHealth(_ value: HealthSyncConfiguration) throws {
        try transaction {
            try putRuntime(.configuration(value))
            for item in try healthMetadata() {
                if case .job(let job) = item, job.userInitiated != true, !value.enabled || !value.writing.contains(job.component), let row = try row(job.key) { modelContext.delete(row) }
                // Populate aliases for pre-U7 installation-local metadata.
                if case .link(let link) = item, try row("current:\(link.businessID):\(link.component.rawValue)") == nil { try storeHealthLink(link) }
                if case .suppression(let suppression) = item, suppression.businessID != nil { try storeHealthSuppression(suppression) }
            }
        }
    }
    func recordHealthCheck(_ value: HealthCheck) throws { try transaction { try putRuntime(.check(value)) } }
    func saveActivity(_ values: [HealthDailyActivity]) throws {
        for value in values { try DomainValidation.day(value.day); try DomainValidation.number(value.steps, max: 1_000_000); try DomainValidation.number(value.activeEnergyKcal, max: 100_000) }
        try transaction { for value in values { try putRuntime(.activity(value)) } }
    }
    func healthActivity(day: String, timeZoneID: String) throws -> HealthDailyActivity? {
        if case .activity(let value) = try healthRuntimeValue("activity:\(timeZoneID):\(day)") { return value }; return nil
    }
    func raiseHealthFloor(_ identifier: String, version: Int) throws {
        let old: Int = if case .floor(let value) = try healthRuntimeValue("floor:\(identifier)") { value.version } else { 0 }
        if version > old { try putRuntime(.floor(HealthVersionFloor(identifier: identifier, version: version))) }
    }
    func storeHealthLink(_ link: HealthSampleLink) throws {
        try putRuntime(.link(link)); try raiseHealthFloor(link.syncIdentifier, version: link.version)
        let key = "current:\(link.businessID):\(link.component.rawValue)"
        if case .currentLink(let existing) = try healthRuntimeValue(key), existing.version > link.version { return }
        try putRuntime(.currentLink(link))
    }
    func storeHealthSuppression(_ value: HealthSuppression) throws {
        try putRuntime(.suppression(value))
        if value.businessID != nil { try putRuntime(.componentSuppression(value)) }
    }
    func healthJobs() throws -> [HealthWriteJob] {
        let prefix = "job:"
        return try modelContext.fetch(FetchDescriptor<StoredRecord>(predicate: #Predicate { $0.key.starts(with: prefix) })).compactMap {
            try verify($0)
            if case .job(let job) = try RecordCoding.decode(HealthRuntimeRecord.self, from: $0.payload) { return job }; return nil
        }
    }
    func prepareHealthJob(_ job: HealthWriteJob) throws -> HealthWriteJob? {
        let configuration = try healthConfiguration()
        let manualDeletion = job.action == .delete && job.userInitiated == true
        let reconciliationRequired = try healthRuntimeValue("health:reconciliation") == .reconciliationRequired(true)
        guard manualDeletion || (configuration.enabled && configuration.writing.contains(job.component)),
              case .job(var current) = try healthRuntimeValue(job.key), current.desiredRevision == job.desiredRevision,
              manualDeletion || !reconciliationRequired else { return nil }
        if current.syncVersion == nil {
            let identifier = HealthSampleMapper.identifier(job.businessID, job.component)
            let floor: Int = if case .floor(let v) = try healthRuntimeValue("floor:\(identifier)") { v.version } else { 0 }
            guard floor < Int.max - 1 else { throw DataProblem.invalid("健康版本上限") }
            current.syncVersion = max(current.desiredRevision, floor + 1)
            try transaction { try putRuntime(.job(current)) }
        }
        return current
    }
    func completeHealthJob(_ job: HealthWriteJob, sample: HealthSampleValue?) throws {
        try transaction {
            if let sample {
                let link = HealthSampleLink(businessID: job.businessID, component: job.component, sampleUUID: sample.id,
                                            syncIdentifier: HealthSampleMapper.identifier(job.businessID, job.component),
                                            version: sample.syncVersion ?? job.syncVersion ?? job.desiredRevision, sourceBundleID: sample.source, state: .written)
                if case .currentLink(var old) = try healthRuntimeValue("current:\(job.businessID):\(job.component.rawValue)"), old.sampleUUID != sample.id {
                    old.state = .deleted; try putRuntime(.link(old))
                }
                try storeHealthLink(link)
            } else {
                if case .currentLink(var link) = try healthRuntimeValue("current:\(job.businessID):\(job.component.rawValue)") {
                    link.state = .deleted; try storeHealthLink(link)
                }
            }
            // A newer edit may have coalesced while HealthKit was suspended.
            if case .job(let current) = try healthRuntimeValue(job.key), current.desiredRevision == job.desiredRevision,
               current.syncVersion == job.syncVersion, let row = try row(job.key) { modelContext.delete(row) }
        }
    }
    func failHealthJob(_ job: HealthWriteJob, message: String) throws {
        guard case .job(var current) = try healthRuntimeValue(job.key), current.desiredRevision == job.desiredRevision else { return }
        current.attempts += 1; current.errorCategory = message
        try transaction { try putRuntime(.job(current)) }
    }
    func reconcileHealthLinks(_ links: [HealthSampleLink]) throws {
        try transaction {
            for link in links { try storeHealthLink(link) }
            try putRuntime(.reconciliationRequired(false))
        }
    }
    // Deliberate action only: it lifts restore/deletion holds and versions above
    // anything already observed in Health. Connecting never exports history.
    func enqueueHealthHistory() throws {
        let config = try healthConfiguration(), records = try snapshot()
        guard config.enabled, !(try healthMetadata()).contains(.reconciliationRequired(true)) else { throw DataProblem.healthReconciliationRequired }
        try transaction {
            for item in try healthMetadata() {
                switch item {
                case .hold: if let row = try row(item.key) { modelContext.delete(row) }
                case .suppression(let suppression), .componentSuppression(let suppression):
                    if suppression.businessID != nil, let row = try row(item.key) { modelContext.delete(row) }
                default: break
                }
            }
            for record in records where record.stamp.deletedAt == nil {
                for component in config.writing where (try? validateComponent(component, record: record)) == true {
                    try putRuntime(.job(HealthWriteJob(businessID: record.id, desiredRevision: record.stamp.revision, component: component, action: .write)))
                }
            }
        }
    }
    func hideHealthSample(_ sample: HealthSampleValue) throws {
        try transaction {
            try putRuntime(.suppression(HealthSuppression(sampleUUID: sample.id, component: sample.component, reason: "用户隐藏")))
            if let row = try row("external:\(sample.id)") { modelContext.delete(row) }
        }
    }
    func clearHealthCache() throws {
        try transaction {
            for row in try modelContext.fetch(FetchDescriptor<StoredRecord>()) where row.key.hasPrefix("external:") || row.key.hasPrefix("cursor:") || row.key.hasPrefix("activity:") { modelContext.delete(row) }
        }
    }
    func resetLocalData() throws {
        // Keep sync disabled; a fresh profile is a new backup identity. Never
        // delete Health data as a side effect of local reset.
        try transaction {
            for row in try modelContext.fetch(FetchDescriptor<StoredRecord>()) { modelContext.delete(row) }
            let profile = LocalProfile()
            try put(key: "business:\(profile.stamp.id)", kind: "business", value: BusinessRecord.profile(profile))
            try putRuntime(.configuration(HealthSyncConfiguration()))
            try putRuntime(.reconciliationRequired(true))
        }
    }
    func markOwnHealthCopiesRemoved(completed: Bool = true) throws {
        try transaction {
            for item in try healthMetadata() {
                if case .link(var link) = item {
                    link.state = completed ? .deleted : .pendingDelete; try storeHealthLink(link)
                    try storeHealthSuppression(HealthSuppression(sampleUUID: link.sampleUUID, businessID: link.businessID, component: link.component, reason: "用户清理健康副本"))
                }
            }
        }
    }
    func purgeOwnHealthCache(source: String) throws {
        var offset = 0
        while true {
            let page = try healthCachePage(offset: offset, limit: 1000)
            guard !page.isEmpty else { return }
            let own = page.filter { item in
                switch item { case .workout(let v): v.sourceBundleID == source; case .body(let v): v.sourceBundleID == source; case .nutrition(let v): v.sourceBundleID == source; default: false }
            }
            try transaction { for item in own { if let row = try row(item.key) { modelContext.delete(row) } } }
            offset += page.count - own.count
        }
    }
    func associateHealthWorkout(_ value: HealthWorkoutAssociation) throws {
        guard case .workout(let external) = try healthRuntimeValue("external:\(value.sampleUUID)"),
              case .session(let local) = try snapshot().first(where: { $0.id == value.businessID }),
              HealthAggregation.overlaps(local, external) else { throw DataProblem.invalid("请选择时段重叠的已完成训练") }
        try transaction {
            for item in try healthMetadata() {
                if case .association(let old) = item, old.businessID == value.businessID, let row = try row(item.key) { modelContext.delete(row) }
            }
            try putRuntime(.association(value))
        }
    }
}
