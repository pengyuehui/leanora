import Foundation

struct ExerciseCatalog: Codable, Sendable {
    var version: Int
    var source: ContentSource
    var entries: [Entry]

    struct Entry: Codable, Sendable {
        var id: UUID
        var name: String
        var aliases: [String]
        var measurement: ExerciseMeasurement
        var equipment: String
        var muscles: [String]
    }
    static func load() throws -> [Exercise] {
        #if SWIFT_PACKAGE
        let url = Bundle.module.url(forResource: "exercises", withExtension: "json", subdirectory: "Catalog")
        #else
        let url = Bundle.main.url(forResource: "exercises", withExtension: "json")
        #endif
        guard let url else { throw DataProblem.invalid("动作目录文件缺失") }
        let catalog = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        guard catalog.version == 1 else { throw DataProblem.unsupportedVersion }
        let exercises = catalog.entries.map { entry in
            Exercise(stamp: RecordStamp(id: entry.id, revision: 1, createdAt: Date(timeIntervalSince1970: 1_792_454_400), updatedAt: Date(timeIntervalSince1970: 1_792_454_400)),
                     name: entry.name, aliases: entry.aliases, measurement: entry.measurement,
                     equipment: entry.equipment, muscles: entry.muscles, source: catalog.source)
        }
        try DomainValidation.validate(exercises.map(BusinessRecord.exercise), requireProfile: false)
        return exercises
    }
}

extension ExerciseMeasurement: CaseIterable {
    static var allCases: [Self] { [.externalLoad, .bodyweight, .assistedLoad, .duration, .cardio] }
    var title: String {
        switch self {
        case .externalLoad: "负重与次数"
        case .bodyweight: "自重与次数"
        case .assistedLoad: "辅助负重与次数"
        case .duration: "计时"
        case .cardio: "有氧时间与距离"
        }
    }
}

enum ExerciseSearch {
    static func filter(_ values: [Exercise], query: String, muscle: String?, equipment: String?, archived: Bool = false) -> [Exercise] {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return values.filter { value in
            value.stamp.deletedAt == nil && value.isArchived == archived &&
            (muscle == nil || value.muscles.contains(muscle!)) && (equipment == nil || value.equipment == equipment!) &&
            words.allSatisfy { word in ([value.name] + value.aliases).contains { $0.localizedStandardContains(word) } }
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
