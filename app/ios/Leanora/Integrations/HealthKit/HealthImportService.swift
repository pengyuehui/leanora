import Foundation

struct HealthImportService: Sendable {
    let repository: AppModelActor
    let transport: any HealthTransport

    func run(configuration: HealthSyncConfiguration) async throws {
        // Snapshot only local business IDs, never the complete external cache.
        let records = Dictionary(uniqueKeysWithValues: try await repository.snapshot().map { ($0.id, $0) })
        for component in configuration.reading.sorted(by: { $0.rawValue < $1.rawValue }) {
            let initial = HealthImportCursor(installationID: configuration.generation, sampleType: component.rawValue, queryStart: configuration.queryStart)
            var cursor: HealthImportCursor = if case .cursor(let old) = try await repository.healthRuntimeValue(initial.key) { old } else { initial }
            while true {
                try Task.checkCancellation()
                guard try await repository.healthConfiguration() == configuration else { return }
                let page = try await transport.page(component: component, cursor: cursor, limit: 500)
                guard try await repository.healthConfiguration() == configuration else { return }
                var projections: [HealthRuntimeRecord] = [], links: [HealthSampleLink] = []
                for sample in page.samples {
                    if sample.source == transport.sourceBundleID, let identifier = sample.syncIdentifier,
                       let id = HealthSampleMapper.businessID(identifier, component: component),
                       let record = records[id], record.stamp.deletedAt == nil, (try? await repository.validateComponent(component, record: record)) != nil,
                       let version = sample.syncVersion, version > 0 {
                        links.append(HealthSampleLink(businessID: id, component: component, sampleUUID: sample.id,
                                                     syncIdentifier: identifier, version: version, sourceBundleID: sample.source, state: .written))
                    } else { projections.append(try HealthSampleMapper.projection(sample)) }
                }
                guard !page.hasMore || page.anchor != cursor.anchor else { throw DataProblem.invalid("健康分页未推进") }
                cursor.anchor = page.anchor
                try await repository.commitHealthImport(projections, deletedSampleIDs: page.deleted, cursor: cursor, links: links)
                if !page.hasMore { break }
            }
        }
        if configuration.readActivity {
            let values = try await transport.activity(from: Date().addingTimeInterval(-30 * 86_400), to: Date(), timeZoneID: TimeZone.current.identifier)
            guard try await repository.healthConfiguration() == configuration else { return }
            try await repository.saveActivity(values)
        }
    }
}
