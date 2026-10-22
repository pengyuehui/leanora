import Foundation

// Bundled teaching content is separate from business records and workout snapshots.
// Catalog updates therefore do not enlarge backups or rewrite a user's history.
struct ExerciseGuide: Decodable, Sendable {
    let exerciseID: UUID
    let demoName: String
    let category: String
    let level: String
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let instructions: [String]
    let originalInstructions: [String]
    let images: [String]
    let sourceName: String
    let sourceURL: String
    let license: String
    let licenseURL: String
    let credit: String
    let modifications: String
    let variantNote: String?
}

enum ExerciseGuideCatalog {
    private struct Document: Decodable { let version: Int; let entries: [ExerciseGuide] }
    private static let bundled: Result<[UUID: ExerciseGuide], Error> = Result {
        #if SWIFT_PACKAGE
        let url = Bundle.module.url(forResource: "exercise-guides", withExtension: "json", subdirectory: "Catalog")
        #else
        let url = Bundle.main.url(forResource: "exercise-guides", withExtension: "json")
        #endif
        guard let url else { throw DataProblem.invalid("动作指导文件缺失") }
        let document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: url))
        guard document.version == 1 else { throw DataProblem.unsupportedVersion }
        guard Set(document.entries.map(\.exerciseID)).count == document.entries.count else { throw DataProblem.invalid("重复的动作指导") }
        for guide in document.entries {
            guard !guide.demoName.isEmpty, (1...3).contains(guide.images.count),
                  guide.images.allSatisfy(validImagePath), !guide.credit.isEmpty, !guide.license.isEmpty,
                  URL(string: guide.sourceURL)?.scheme == "https", URL(string: guide.licenseURL)?.scheme == "https"
            else { throw DataProblem.invalid("动作指导来源或素材路径") }
        }
        return Dictionary(uniqueKeysWithValues: document.entries.map { ($0.exerciseID, $0) })
    }

    static func load() throws -> [UUID: ExerciseGuide] { try bundled.get() }
    static func guide(for id: UUID) -> ExerciseGuide? { try? bundled.get()[id] }

    static func validImagePath(_ path: String) -> Bool {
        let components = path.components(separatedBy: "/")
        return (path.hasPrefix("free/") || path.hasPrefix("workout/")) &&
            components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\\") } &&
            ["jpg", "png"].contains((path as NSString).pathExtension)
    }

    static func imageURL(for path: String) -> URL? {
        guard validImagePath(path) else { return nil }
        #if SWIFT_PACKAGE
        let root = Bundle.module.url(forResource: "ExerciseMedia", withExtension: nil)
        #else
        let root = Bundle.main.url(forResource: "ExerciseMedia", withExtension: nil)
        #endif
        return root?.appendingPathComponent(path)
    }
}
