import Foundation

extension AppModelActor {
    func saveWithHealthIntent(_ records: [BusinessRecord], deleteHealthCopies: Bool = false) throws {
        let configuration = try healthConfiguration()
        let reconciliationRequired = try healthRuntimeValue("health:reconciliation") == .reconciliationRequired(true)
        guard (configuration.enabled && !reconciliationRequired) || deleteHealthCopies else { try save(records); return }
        var jobs: [HealthWriteJob] = []
        let oldRecords = Dictionary(uniqueKeysWithValues: try snapshot().map { ($0.id, $0) })
        for record in records {
            if record.stamp.deletedAt != nil && !deleteHealthCopies { continue }
            let components: [(HealthComponent, Bool)]
            switch record {
            case .session(let v): components = v.status == .completed ? [(.workout, true)] : []
            case .measurement(let v): components = [(v.metric == .weightKg ? .weight : .bodyFat, true)]
            case .diet(let v): components = [(.energy, v.nutrients.energyKcal != nil), (.protein, v.nutrients.proteinGrams != nil), (.carbohydrate, v.nutrients.carbohydrateGrams != nil), (.fat, v.nutrients.fatGrams != nil)]
            default: components = []
            }
            for (component, known) in components {
                let held = try healthRuntimeValue("hold:\(record.id)") != nil
                guard deleteHealthCopies || (configuration.writing.contains(component) && !held) else { continue }
                let suppressed = try healthRuntimeValue("blocked:\(record.id):\(component.rawValue)") != nil
                let linked: Bool = if case .currentLink(let l) = try healthRuntimeValue("current:\(record.id):\(component.rawValue)") { l.state != .deleted } else { false }
                let uncertain: Bool = if case .job(let j) = try healthRuntimeValue("job:\(record.id):\(component.rawValue)") { j.syncVersion != nil } else { false }
                let previouslyWritten = linked || uncertain || oldRecords[record.id].map { (try? validateComponent(component, record: $0)) == true } == true
                if (deleteHealthCopies || !suppressed) && (known || previouslyWritten) {
                    jobs.append(HealthWriteJob(businessID: record.id, desiredRevision: record.stamp.revision, component: component,
                                               action: known && record.stamp.deletedAt == nil ? .write : .delete, userInitiated: deleteHealthCopies ? true : nil))
                }
            }
        }
        try save(records, jobs: jobs)
    }
}
