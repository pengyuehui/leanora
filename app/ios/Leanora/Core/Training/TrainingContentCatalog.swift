import Foundation

struct TrainingContentCatalog: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        let exerciseID: UUID
        let sets: Int
        let minimumReps: Int?
        let maximumReps: Int?
        let seconds: Double?
        let restSeconds: Double
    }
    struct Template: Decodable, Identifiable, Sendable {
        let id: String
        let title: String
        let items: [Item]
    }
    struct Program: Decodable, Identifiable, Sendable {
        let id: String
        let title: String
        let subtitle: String
        let equipment: String
        let summary: String
        let templates: [Template]
    }
    struct Guide: Decodable, Identifiable, Sendable {
        struct Section: Decodable, Sendable {
            let title: String
            let paragraphs: [String]
        }
        let id: String
        let title: String
        let summary: String
        let sections: [Section]
    }
    let version: Int
    let author: String
    let license: String
    let programs: [Program]
    let guides: [Guide]

    private static let bundled: Result<TrainingContentCatalog, Error> = Result {
        #if SWIFT_PACKAGE
        let url = Bundle.module.url(forResource: "training-content", withExtension: "json", subdirectory: "Catalog")
        #else
        let url = Bundle.main.url(forResource: "training-content", withExtension: "json")
        #endif
        guard let url else { throw DataProblem.invalid("训练内容文件缺失") }
        return try decode(Data(contentsOf: url), exercises: ExerciseCatalog.load())
    }

    static func load() throws -> TrainingContentCatalog { try bundled.get() }

    static func decode(_ data: Data, exercises: [Exercise]) throws -> TrainingContentCatalog {
        guard data.count <= 2 * 1024 * 1024 else { throw DataProblem.tooLarge }
        let document = try JSONDecoder().decode(Self.self, from: data)
        guard document.version == 1 else { throw DataProblem.unsupportedVersion }
        guard document.license == "MIT", !document.author.isEmpty,
              !document.programs.isEmpty, document.programs.count <= 100, !document.guides.isEmpty, document.guides.count <= 100 else { throw DataProblem.invalid("训练内容来源或数量") }
        let ids = document.programs.map(\.id) + document.programs.flatMap { $0.templates.map(\.id) } + document.guides.map(\.id)
        guard ids.allSatisfy({ !$0.isEmpty }), Set(ids).count == ids.count else { throw DataProblem.invalid("重复的训练内容标识") }
        for program in document.programs {
            try DomainValidation.text(program.title, required: true); try DomainValidation.text(program.summary, required: true)
            guard !program.templates.isEmpty, program.templates.count <= 20 else { throw DataProblem.invalid("范例训练日") }
            _ = try document.makeTemplates(programID: program.id, exercises: exercises)
        }
        for guide in document.guides {
            try DomainValidation.text(guide.title, required: true); try DomainValidation.text(guide.summary, required: true)
            guard !guide.sections.isEmpty, guide.sections.count <= 20 else { throw DataProblem.invalid("记录指南章节") }
            for section in guide.sections {
                try DomainValidation.text(section.title, required: true)
                guard !section.paragraphs.isEmpty, section.paragraphs.count <= 20 else { throw DataProblem.invalid("记录指南正文") }
                for paragraph in section.paragraphs { try DomainValidation.text(paragraph, required: true) }
            }
        }
        return document
    }

    func makeTemplates(programID: String, exercises: [Exercise]) throws -> [WorkoutTemplate] {
        guard let program = programs.first(where: { $0.id == programID }) else { throw TrainingProblem.missingRecord }
        let available = Dictionary(uniqueKeysWithValues: exercises.map { ($0.stamp.id, $0) })
        let templates = try program.templates.map { preset in
            guard !preset.items.isEmpty, preset.items.count <= 20 else { throw TrainingProblem.emptyTemplate }
            let items = try preset.items.enumerated().map { index, spec in
                guard let exercise = available[spec.exerciseID], exercise.stamp.deletedAt == nil else { throw TrainingProblem.missingRecord }
                guard !exercise.isArchived else { throw TrainingProblem.archivedExercise }
                guard exercise.measurement == .duration ? spec.seconds != nil && spec.minimumReps == nil :
                    [.externalLoad, .bodyweight].contains(exercise.measurement) && spec.minimumReps != nil && spec.seconds == nil else { throw TrainingProblem.invalidTargets }
                return TemplateItem(exerciseID: exercise.stamp.id, order: index, plannedSets: spec.sets,
                                    minimumReps: spec.minimumReps, maximumReps: spec.maximumReps,
                                    durationSeconds: spec.seconds, restSeconds: spec.restSeconds)
            }
            return WorkoutTemplate(name: preset.title, items: items,
                notes: "Leanora 原创范例 · \(program.title)\n可按实际调整，目标负重留空。采用后请自行安排训练日。")
        }
        let used = Set(templates.flatMap { $0.items.map(\.exerciseID) })
        try DomainValidation.validate(exercises.filter { used.contains($0.stamp.id) }.map(BusinessRecord.exercise) + templates.map(BusinessRecord.template), requireProfile: false)
        return templates
    }
}
