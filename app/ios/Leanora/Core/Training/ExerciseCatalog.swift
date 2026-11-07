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
        var source: ContentSource?
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
                     equipment: entry.equipment, muscles: entry.muscles, source: entry.source ?? catalog.source)
        }
        try DomainValidation.validate(exercises.map(BusinessRecord.exercise), requireProfile: false)
        let guides = try ExerciseGuideCatalog.load()
        guard Set(exercises.map { $0.stamp.id }) == Set(guides.keys) else { throw DataProblem.invalid("动作指导目录不完整") }
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
    static func filter(_ values: [Exercise], query: String, muscle: String?, equipment: String?, archived: Bool = false,
                       level: String? = nil, category: String? = nil) -> [Exercise] {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return values.filter { value in
            let guide = ExerciseGuideCatalog.guide(for: value.stamp.id)
            let muscles = value.muscles + (guide.map { $0.primaryMuscles + $0.secondaryMuscles } ?? [])
            let fields = [value.name, value.equipment] + value.aliases + muscles + (guide.map { [$0.level, $0.category] } ?? [])
            return value.stamp.deletedAt == nil && value.isArchived == archived &&
            (muscle == nil || muscles.contains(muscle!)) && (equipment == nil || value.equipment == equipment!) &&
            (level == nil || guide?.level == level) && (category == nil || guide?.category == category) &&
            words.allSatisfy { word in fields.contains { $0.localizedStandardContains(word) } }
        }.sorted {
            let leftChinese = $0.name.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
            let rightChinese = $1.name.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
            if leftChinese != rightChinese { return leftChinese }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}

enum ExerciseRegion: String, CaseIterable, Identifiable {
    case all = "全部", chest = "胸", back = "背", legs = "腿", shoulders = "肩"
    case biceps = "二头", triceps = "三头", forearms = "前臂", glutes = "臀", core = "核心"
    case cardio = "有氧", stretch = "拉伸", neck = "颈部", other = "其他"
    var id: Self { self }
    var muscles: Set<String> {
        switch self {
        case .chest: ["胸部"]
        case .back: ["背部", "背阔肌", "中背部", "下背部", "斜方肌"]
        case .legs: ["下肢", "股四头肌", "腘绳肌", "小腿", "髋内收肌群", "髋外展肌群"]
        case .shoulders: ["肩部", "上肢"]
        case .biceps: ["肱二头肌", "手臂"]
        case .triceps: ["肱三头肌", "手臂"]
        case .forearms: ["前臂"]
        case .glutes: ["臀部"]
        case .core: ["核心", "腹肌"]
        case .cardio: ["心肺"]
        case .neck: ["颈部"]
        default: []
        }
    }
    func contains(_ exercise: Exercise) -> Bool {
        switch self {
        case .all: true
        case .stretch: ExerciseGuideCatalog.guide(for: exercise.stamp.id)?.category == "拉伸"
        case .cardio: exercise.measurement == .cardio || !muscles.isDisjoint(with: exercise.muscles)
        case .other: !Self.allCases.filter { ![.all, .other].contains($0) }.contains { $0.contains(exercise) }
        default: !muscles.isDisjoint(with: exercise.muscles)
        }
    }
}
