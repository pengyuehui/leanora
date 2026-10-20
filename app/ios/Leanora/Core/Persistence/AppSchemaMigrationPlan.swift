import Foundation
import SwiftData

// Domain payloads are typed, versioned Codable values. A document per aggregate
// keeps historical children in the parent's atomic save, without cascade deletes.
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [StoredRecord.self] }

    @Model final class StoredRecord {
        @Attribute(.unique) var key: String
        var kind: String
        var payload: Data
        init(key: String, kind: String, payload: Data) {
            self.key = key; self.kind = kind; self.payload = payload
        }
    }
}
enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [StoredRecord.self] }

    @Model final class StoredRecord {
        @Attribute(.unique) var key: String
        var kind: String
        var payload: Data
        // Nullable additive field: old payloads and IDs are preserved verbatim.
        var contentDigest: String?
        init(key: String, kind: String, payload: Data, contentDigest: String? = nil) {
            self.key = key; self.kind = kind; self.payload = payload; self.contentDigest = contentDigest
        }
    }
}
enum AppSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self, AppSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: AppSchemaV1.self, toVersion: AppSchemaV2.self)]
    }
}
typealias StoredRecord = AppSchemaV2.StoredRecord
