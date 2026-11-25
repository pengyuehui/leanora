import Foundation

enum HealthPromptStatus: String, Sendable { case unknown, shouldRequest, unnecessary }

// Only request metadata. Never include sample values, account identifiers,
// device identifiers or arbitrary localized error descriptions in diagnostics.
struct HealthAuthorizationDiagnostic: Sendable {
    var attemptedAt = Date()
    var appVersion: String
    var build: String
    var systemVersion: String
    var applicationState: String
    var reading: [String]
    var writing: [String]
    var promptStatus: HealthPromptStatus = .unknown
    var outcome = "requesting"
    var writableCount: Int?
    var errorCode: String?

    var text: String {
        var rows = ["Leanora Health authorization diagnostic", "Version: \(appVersion) (\(build))", "System: \(systemVersion)",
                    "Time: \(attemptedAt.ISO8601Format())", "Application: \(applicationState)",
                    "Read types: \(reading.sorted().joined(separator: ", "))", "Write types: \(writing.sorted().joined(separator: ", "))",
                    "Permission sheet: \(promptStatus.rawValue)", "Outcome: \(outcome)"]
        if let writableCount { rows.append("Writable types: \(writableCount)/\(writing.count)") }
        if let errorCode { rows.append("Error: \(errorCode)") }
        rows.append("Read authorization is not observable. No health sample values are included.")
        return rows.joined(separator: "\n")
    }
}
