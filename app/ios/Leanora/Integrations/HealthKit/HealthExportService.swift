import Foundation

struct HealthExportService: Sendable {
    let repository: AppModelActor
    let transport: any HealthTransport

    func run() async throws {
        var attempted = Set<String>()
        // Drain new coalesced edits as well, but never spin on a denied component.
        while true {
            let jobs = try await repository.healthJobs().filter { !attempted.contains("\($0.key):\($0.desiredRevision)") }
            guard !jobs.isEmpty else { return }
            for pending in jobs {
                try Task.checkCancellation()
                attempted.insert("\(pending.key):\(pending.desiredRevision)")
                guard let job = try await repository.prepareHealthJob(pending) else { continue }
                do {
                    guard await transport.canWrite(job.component) else { throw HealthTransportProblem.writeDenied }
                    let identifier = HealthSampleMapper.identifier(job.businessID, job.component)
                    if job.action == .delete {
                        try await transport.deleteOwn(identifier: identifier, component: job.component)
                        try await repository.completeHealthJob(job, sample: nil)
                    } else {
                        guard let record = try await repository.snapshot().first(where: { $0.id == job.businessID }),
                              record.stamp.revision == job.desiredRevision,
                              let sample = try HealthSampleMapper.export(record, component: job.component, version: job.syncVersion!, source: transport.sourceBundleID) else { continue }
                        // If Health succeeded before a crash, recover its actual
                        // UUID. Older/equal retries never overwrite newer data.
                        let existing = try await transport.findOwn(identifier: identifier, component: job.component)
                        let written: HealthSampleValue
                        if let existing, (existing.syncVersion ?? 0) >= job.syncVersion! { written = existing }
                        else { written = try await transport.write(sample) }
                        try await repository.completeHealthJob(job, sample: written)
                    }
                } catch is CancellationError { throw CancellationError() }
                catch {
                    let message: String
                    if case .unconfirmedWrite = error as? HealthTransportProblem { message = "健康写入暂未确认，已有本机记录保留，请检查健康访问后重试" }
                    else { message = error is HealthTransportProblem ? "检查健康写入权限后重试" : "健康暂不可用，请解锁后重试" }
                    try await repository.failHealthJob(job, message: message)
                }
            }
        }
    }

    func reconcile() async throws {
        let records = try await repository.snapshot()
        var links: [HealthSampleLink] = []
        for record in records {
            for component in HealthComponent.allCases where (try? await repository.validateComponent(component, record: record)) != nil {
                let identifier = HealthSampleMapper.identifier(record.id, component)
                if let sample = try await transport.findOwn(identifier: identifier, component: component), let version = sample.syncVersion {
                    links.append(HealthSampleLink(businessID: record.id, component: component, sampleUUID: sample.id,
                                                 syncIdentifier: identifier, version: version, sourceBundleID: sample.source, state: .written))
                }
            }
        }
        try await repository.reconcileHealthLinks(links)
    }
}
