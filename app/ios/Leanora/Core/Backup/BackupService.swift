import Foundation
import CryptoKit

enum RecordCoding {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        // Milliseconds retain ordering/precision without ISO8601's truncated seconds.
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(value)
    }
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(type, from: data)
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func fingerprint(_ records: [BusinessRecord]) throws -> String {
        try digest(encode(records.sorted { $0.id.uuidString < $1.id.uuidString }))
    }
}

struct BackupDocument: Codable, Equatable, Sendable {
    var format = "app.leanora.backup"
    var version = 2
    var exportedAt = Date()
    var profileID: UUID
    var records: [BusinessRecord]
}
struct BackupExport: Sendable {
    let data: Data
    let fingerprint: String
}
struct PreparedImport: Sendable {
    let document: BackupDocument
    let originalFingerprint: String
    let incoming: Int
    let newer: Int
    let older: Int
    let identical: Int
    let conflicts: Int
    let differentIdentity: Bool
}
struct ImportOutcome: Equatable, Sendable {
    var inserted = 0
    var updated = 0
    var skipped = 0
    var conflicts = 0
}

enum BackupService {
    static let maximumBytes = 50 * 1024 * 1024

    static func decode(_ data: Data) throws -> BackupDocument {
        guard data.count <= maximumBytes else { throw DataProblem.tooLarge }
        struct Header: Decodable { var format: String; var version: Int }
        let header: Header
        do { header = try RecordCoding.decode(Header.self, from: data) }
        catch { throw DataProblem.invalid("JSON 格式") }
        guard header.format == "app.leanora.backup", [1, 2].contains(header.version) else { throw DataProblem.unsupportedVersion }
        let document: BackupDocument
        do { document = try RecordCoding.decode(BackupDocument.self, from: data) }
        catch { throw DataProblem.invalid("JSON 记录或 UUID") }
        if document.version == 1, document.records.contains(where: { $0.kind == "mealTemplate" }) { throw DataProblem.unsupportedVersion }
        try DomainValidation.validate(document.records)
        guard document.records.contains(where: { $0.kind == "profile" && $0.id == document.profileID }) else { throw DataProblem.invalid("备份身份") }
        return document
    }

    // Read in bounded chunks even if a provider misreports size or changes the file.
    static func readFile(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
            guard data.count + chunk.count <= maximumBytes else { throw DataProblem.tooLarge }
            data.append(chunk)
        }
        return data
    }

    static func prepare(_ data: Data, current: [BusinessRecord]) throws -> PreparedImport {
        let document = try decode(data)
        let existing = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        var inserted = 0, newer = 0, older = 0, identical = 0, conflicts = 0
        for record in document.records {
            guard let old = existing[record.id] else { inserted += 1; continue }
            guard record.kind == old.kind else { throw DataProblem.invalid("UUID 类型变化") }
            if record.stamp.revision > old.stamp.revision { newer += 1 }
            else if record.stamp.revision < old.stamp.revision { older += 1 }
            else if try RecordCoding.encode(record) == RecordCoding.encode(old) { identical += 1 }
            else { conflicts += 1 }
        }
        let hasBusiness = current.contains { $0.kind != "profile" }
        let foreign = hasBusiness && !current.contains { $0.kind == "profile" && $0.id == document.profileID }
        return PreparedImport(document: document, originalFingerprint: try RecordCoding.fingerprint(current),
                              incoming: inserted, newer: newer, older: older, identical: identical,
                              conflicts: conflicts, differentIdentity: foreign)
    }

    static func merge(_ preview: PreparedImport, current: [BusinessRecord], acceptNewer: Bool,
                      replace: Bool, exportedFingerprint: String?) throws -> ([BusinessRecord], ImportOutcome) {
        guard try RecordCoding.fingerprint(current) == preview.originalFingerprint else { throw DataProblem.stalePreview }
        if preview.differentIdentity {
            guard replace else { throw DataProblem.identityMismatch }
            guard exportedFingerprint == preview.originalFingerprint else { throw DataProblem.exportRequired }
            return (preview.document.records, ImportOutcome(inserted: preview.document.records.count))
        }
        // A fresh installation's generated profile does not prevent identity adoption.
        var merged = Dictionary(uniqueKeysWithValues: current.filter {
            $0.kind != "profile" || $0.id == preview.document.profileID
        }.map { ($0.id, $0) })
        var result = ImportOutcome()
        for record in preview.document.records {
            if let old = merged[record.id] {
                if record.stamp.revision > old.stamp.revision && acceptNewer { merged[record.id] = record; result.updated += 1 }
                else {
                    result.skipped += 1
                    if record.stamp.revision == old.stamp.revision,
                       try RecordCoding.encode(record) != RecordCoding.encode(old) { result.conflicts += 1 }
                }
            } else { merged[record.id] = record; result.inserted += 1 }
        }
        let records = Array(merged.values)
        try DomainValidation.validate(records)
        return (records, result)
    }
}
