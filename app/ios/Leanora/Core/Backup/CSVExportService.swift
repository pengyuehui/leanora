import Foundation

enum CSVExportService {
    static let columns = ["type", "id", "parent_id", "occurred_at", "time_zone", "local_date", "name", "meal", "set_order", "set_kind", "load_kg", "repetitions", "duration_seconds", "distance_meters", "energy_kcal", "protein_g", "carbohydrate_g", "fat_g", "weight_kg", "body_fat_percent", "source"]
    static func encode(_ records: [BusinessRecord]) throws -> Data {
        try DomainValidation.validate(records)
        let date = ISO8601DateFormatter()
        var rows = [columns.joined(separator: ",")]
        func append(_ fields: [String: String]) {
            rows.append(columns.map { escape(fields[$0] ?? "") }.joined(separator: ","))
        }
        func base(_ record: BusinessRecord, moment: RecordMoment, name: String) -> [String: String] {
            ["type": record.kind, "id": record.id.uuidString, "occurred_at": date.string(from: moment.instant), "time_zone": moment.timeZoneID, "local_date": moment.localDate, "name": name, "source": "Leanora"]
        }
        for record in records.sorted(by: { $0.id.uuidString < $1.id.uuidString }) where record.stamp.deletedAt == nil {
            switch record {
            case .session(let session):
                var row = base(record, moment: session.started, name: session.name)
                row["duration_seconds"] = session.endedAt.map { String(max(0, $0.timeIntervalSince(session.started.instant) - session.pauses.reduce(0) { $0 + ($1.endedAt ?? $1.startedAt).timeIntervalSince($1.startedAt) })) }
                append(row)
                for exercise in session.exercises.sorted(by: { $0.order < $1.order }) {
                    for set in exercise.sets.sorted(by: { $0.order < $1.order }) where set.completedAt != nil {
                        var row = base(record, moment: session.started, name: exercise.snapshot.name)
                        row["type"] = "set"; row["id"] = set.id.uuidString; row["parent_id"] = session.stamp.id.uuidString
                        row["set_order"] = String(set.order + 1); row["set_kind"] = set.kind.rawValue
                        row["load_kg"] = set.loadKg.map(String.init(describing:)); row["repetitions"] = set.repetitions.map(String.init)
                        row["duration_seconds"] = set.durationSeconds.map(String.init(describing:)); row["distance_meters"] = set.distanceMeters.map(String.init(describing:))
                        append(row)
                    }
                }
            case .diet(let entry):
                var row = base(record, moment: entry.occurred, name: entry.food?.name ?? entry.name)
                row["meal"] = entry.meal.rawValue; row["energy_kcal"] = entry.nutrients.energyKcal.map(String.init(describing:))
                row["protein_g"] = entry.nutrients.proteinGrams.map(String.init(describing:)); row["carbohydrate_g"] = entry.nutrients.carbohydrateGrams.map(String.init(describing:)); row["fat_g"] = entry.nutrients.fatGrams.map(String.init(describing:))
                append(row)
            case .measurement(let measurement):
                var row = base(record, moment: measurement.occurred, name: measurement.metric.rawValue)
                row[measurement.metric == .weightKg ? "weight_kg" : "body_fat_percent"] = String(measurement.value); append(row)
            default: break
            }
        }
        return Data(("\u{FEFF}" + rows.joined(separator: "\r\n") + "\r\n").utf8)
    }
    static func escape(_ value: String) -> String {
        // CSV quotes alone do not prevent spreadsheet formula execution.
        let first = value.trimmingCharacters(in: .whitespacesAndNewlines).first
        let safe = first.map { "=+-@".contains($0) } == true ? "'" + value : value
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
extension AppModelActor {
    func exportCSV() throws -> Data { try CSVExportService.encode(snapshot()) }
}
