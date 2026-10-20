import Foundation

extension AppModelActor {
    // U4/U5 persist desired components only. U7 will apply explicit user export
    // settings and authorization before executing these inert jobs. Restores never
    // enqueue a write; ordinary local editing remains available behind that gate.
    func saveWithHealthIntent(_ records: [BusinessRecord]) throws {
        let runtime = try runtimeSnapshot()
        guard !runtime.contains(.reconciliationRequired(true)) else { try save(records); return }
        var jobs: [HealthWriteJob] = []
        for record in records {
            let components: [(HealthComponent, Bool)]
            switch record {
            case .session(let v): components = v.status == .completed ? [(.workout, true)] : []
            case .measurement(let v): components = [(v.metric == .weightKg ? .weight : .bodyFat, true)]
            case .diet(let v): components = [(.energy, v.nutrients.energyKcal != nil), (.protein, v.nutrients.proteinGrams != nil), (.carbohydrate, v.nutrients.carbohydrateGrams != nil), (.fat, v.nutrients.fatGrams != nil)]
            default: components = []
            }
            for (component, known) in components {
                let suppressed = runtime.contains { if case .suppression(let s) = $0 { return s.businessID == record.id && s.component == component }; return false }
                let previouslyWritten = runtime.contains { if case .link(let l) = $0 { return l.businessID == record.id && l.component == component && l.state != .deleted }; return false }
                if !suppressed && (known || previouslyWritten) {
                    jobs.append(HealthWriteJob(businessID: record.id, desiredRevision: record.stamp.revision, component: component,
                                               action: known && record.stamp.deletedAt == nil ? .write : .delete))
                }
            }
        }
        try save(records, jobs: jobs)
    }
}
