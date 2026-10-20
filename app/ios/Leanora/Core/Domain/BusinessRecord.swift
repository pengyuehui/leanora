import Foundation

enum BusinessRecord: Codable, Equatable, Sendable {
    case profile(LocalProfile), exercise(Exercise), template(WorkoutTemplate), session(WorkoutSession)
    case food(Food), diet(DietEntry), goal(NutritionGoal), measurement(BodyMeasurement)
    case schedule(WorkoutDayChange)

    var stamp: RecordStamp {
        switch self {
        case .profile(let v): v.stamp
        case .exercise(let v): v.stamp
        case .template(let v): v.stamp
        case .session(let v): v.stamp
        case .food(let v): v.stamp
        case .diet(let v): v.stamp
        case .goal(let v): v.stamp
        case .measurement(let v): v.stamp
        case .schedule(let v): v.stamp
        }
    }
    var kind: String {
        switch self {
        case .profile: "profile"
        case .exercise: "exercise"
        case .template: "template"
        case .session: "session"
        case .food: "food"
        case .diet: "diet"
        case .goal: "goal"
        case .measurement: "measurement"
        case .schedule: "schedule"
        }
    }
    var id: UUID { stamp.id }
    var nestedIDs: [UUID] {
        switch self {
        case .template(let v): v.items.map(\.id)
        case .session(let v): v.exercises.flatMap { [$0.id] + $0.sets.map(\.id) }
        case .food(let v): v.units.map(\.id)
        default: []
        }
    }
}

enum DataProblem: Error, LocalizedError, Equatable {
    case invalid(String), unsupportedVersion, tooLarge, tooManyRecords, stalePreview
    case identityMismatch, exportRequired, revisionConflict, healthReconciliationRequired

    var errorDescription: String? {
        switch self {
        case .invalid(let field): "数据校验未通过：\(field)。原有记录未更改。"
        case .unsupportedVersion: "不支持此备份版本，请使用兼容版本的 Leanora。"
        case .tooLarge: "备份超过 50MB，无法导入。"
        case .tooManyRecords: "备份超过 10 万条业务记录，无法导入。"
        case .stalePreview: "本机数据已变化，请重新预览备份。"
        case .identityMismatch: "这是另一个本机身份的备份，需要先导出当前数据再确认整库替换。"
        case .exportRequired: "请先成功导出当前数据，再进行整库替换。"
        case .revisionConflict: "记录版本已变化，请重新读取后保存。"
        case .healthReconciliationRequired: "恢复后需重新连接健康并核对已有样本，暂不创建健康写入任务。"
        }
    }
}

enum DomainValidation {
    static let maximumRecords = 100_000

    static func validate(_ records: [BusinessRecord], requireProfile: Bool = true) throws {
        guard records.count <= maximumRecords,
              records.reduce(0, { $0 + 1 + $1.nestedIDs.count }) <= maximumRecords else { throw DataProblem.tooManyRecords }
        var ids = Set<UUID>()
        let profiles = records.filter { $0.kind == "profile" }
        guard requireProfile ? profiles.count == 1 : profiles.count <= 1 else { throw DataProblem.invalid("本机身份") }
        let kinds = Dictionary(records.map { ($0.id, $0.kind) }, uniquingKeysWith: { first, _ in first })
        func reference(_ id: UUID?, _ kind: String) throws {
            if let id, kinds[id] != kind { throw DataProblem.invalid("记录引用") }
        }
        for record in records {
            for id in [record.id] + record.nestedIDs {
                guard ids.insert(id).inserted else { throw DataProblem.invalid("重复 UUID") }
            }
            let s = record.stamp
            guard s.revision > 0, s.revision < Int.max, s.createdAt.timeIntervalSince1970.isFinite,
                  s.updatedAt >= s.createdAt, s.updatedAt.timeIntervalSince1970.isFinite,
                  s.deletedAt == nil || s.deletedAt! >= s.createdAt else { throw DataProblem.invalid("修订或时间") }
            switch record {
            case .profile(let v):
                guard ["kg", "lb"].contains(v.weightUnit), ["km", "mi"].contains(v.distanceUnit),
                      TimeZone(identifier: v.timeZoneID) != nil, s.deletedAt == nil,
                      v.weeklyTrainingDays.map({ (1...7).contains($0) }) ?? true else { throw DataProblem.invalid("身份偏好") }
            case .exercise(let v):
                try text(v.name, required: true); try strings(v.aliases); try strings(v.muscles)
                try text(v.equipment); try source(v.source)
            case .template(let v):
                try text(v.name, required: true); try text(v.notes)
                guard Set(v.scheduledWeekdays).count == v.scheduledWeekdays.count,
                      v.scheduledWeekdays.allSatisfy({ (1...7).contains($0) }) else { throw DataProblem.invalid("周安排") }
                try orders(v.items.map(\.order))
                for item in v.items {
                    try reference(item.exerciseID, "exercise")
                    guard (1...1000).contains(item.plannedSets) else { throw DataProblem.invalid("计划组数") }
                    try integer(item.minimumReps); try integer(item.maximumReps)
                    if let a = item.minimumReps, let b = item.maximumReps, a > b { throw DataProblem.invalid("次数范围") }
                    try number(item.loadKg, max: 5000); try number(item.durationSeconds, max: 604800)
                    try number(item.distanceMeters, max: 10_000_000); try number(item.restSeconds, max: 86400)
                }
                try supersets(v.items.map { ($0.supersetID, $0.exerciseID) }, kinds: records)
            case .session(let v):
                try text(v.name, required: true); try text(v.notes); try moment(v.started)
                try reference(v.templateID, "template")
                if let revision = v.templateRevision, revision < 1 { throw DataProblem.invalid("模板版本") }
                if let end = v.endedAt, end < v.started.instant { throw DataProblem.invalid("训练结束时间") }
                if [.completed, .abandoned].contains(v.status), v.endedAt == nil { throw DataProblem.invalid("训练终态") }
                try orders(v.exercises.map(\.order))
                var previousEnd = v.started.instant
                for (index, pause) in v.pauses.enumerated() {
                    guard pause.startedAt >= previousEnd, pause.endedAt == nil || pause.endedAt! >= pause.startedAt,
                          pause.endedAt != nil || (index == v.pauses.count - 1 && v.status == .paused),
                          v.endedAt == nil || (pause.endedAt != nil && pause.endedAt! <= v.endedAt!) else {
                        throw DataProblem.invalid("暂停区间")
                    }
                    previousEnd = pause.endedAt ?? pause.startedAt
                }
                for exercise in v.exercises {
                    try reference(exercise.snapshot.exerciseID, "exercise")
                    try text(exercise.snapshot.name, required: true); try text(exercise.notes)
                    if let targets = exercise.plannedTargets {
                        guard (1...1000).contains(targets.sets) else { throw DataProblem.invalid("快照计划组数") }
                        try integer(targets.minimumReps); try integer(targets.maximumReps)
                        if let a = targets.minimumReps, let b = targets.maximumReps, a > b { throw DataProblem.invalid("快照次数范围") }
                        try number(targets.loadKg, max: 5000); try number(targets.durationSeconds, max: 604800)
                        try number(targets.distanceMeters, max: 10_000_000); try number(targets.restSeconds, max: 86400)
                    }
                    guard exercise.snapshot.revision > 0 else { throw DataProblem.invalid("动作快照版本") }
                    try orders(exercise.sets.map(\.order))
                    for set in exercise.sets {
                        try number(set.loadKg, max: 5000); try integer(set.repetitions)
                        try number(set.durationSeconds, max: 604800); try number(set.distanceMeters, max: 10_000_000)
                        try number(set.accumulatedSeconds, max: 604800)
                        if let effort = set.effort { try number(effort.value, max: 10) }
                    }
                }
                if let day = v.scheduleOriginDate { try self.day(day) }
                let groups = Dictionary(grouping: v.exercises.filter { $0.supersetID != nil }, by: { $0.supersetID! })
                guard groups.values.allSatisfy({ $0.count == 2 && $0.allSatisfy { [.externalLoad, .bodyweight, .assistedLoad].contains($0.snapshot.measurement) } }) else { throw DataProblem.invalid("超级组") }
            case .food(let v):
                try text(v.name, required: true); try strings(v.aliases); try nutrients(v.nutrientsPer100Grams)
                try source(v.source)
                for unit in v.units {
                    try text(unit.name, required: true); try number(unit.grams, min: 0.000001, max: 100_000)
                    if let volume = unit.milliliters {
                        try number(volume, min: 0.000001, max: 100_000)
                        guard let source = unit.conversionSource else { throw DataProblem.invalid("体积换算来源") }
                        try text(source, required: true)
                    }
                }
            case .diet(let v):
                try moment(v.occurred); try text(v.name); try text(v.unitName, required: true); try text(v.notes)
                try number(v.quantity, min: 0.000001, max: 100_000); try number(v.grams, min: 0.000001, max: 100_000)
                try nutrients(v.nutrients)
                guard v.nutrients.energyKcal != nil || v.food != nil else { throw DataProblem.invalid("快速记录热量") }
                if let food = v.food {
                    try reference(food.foodID, "food"); try text(food.name, required: true)
                    try nutrients(food.nutrientsPer100Grams); try source(food.source)
                    guard food.revision > 0, v.grams != nil else { throw DataProblem.invalid("食物快照") }
                }
            case .goal(let v):
                try day(v.effectiveFrom); try nutrients(v.nutrients)
                try number(v.nutrients.energyKcal, min: 1, max: 20_000)
                if let energy = v.nutrients.energyKcal, energy.rounded() != energy { throw DataProblem.invalid("每日热量目标") }
                guard TimeZone(identifier: v.timeZoneID) != nil else { throw DataProblem.invalid("目标时区") }
            case .measurement(let v):
                try moment(v.occurred); try source(v.source)
                try number(v.value, min: 0.000001, max: v.metric == .weightKg ? 1500 : 100)
            case .schedule(let v):
                try reference(v.templateID, "template")
                try day(v.originDate); try day(v.destinationDate)
                guard TimeZone(identifier: v.timeZoneID) != nil else { throw DataProblem.invalid("改期时区") }
            }
        }
        let active = records.filter {
            if case .session(let v) = $0 { return v.stamp.deletedAt == nil && [.active, .paused].contains(v.status) }
            return false
        }
        guard active.count <= 1 else { throw DataProblem.invalid("同时进行的训练") }
        let changes = records.compactMap { record -> String? in
            if case .schedule(let v) = record, v.stamp.deletedAt == nil { return "\(v.templateID):\(v.originDate)" }; return nil
        }
        guard Set(changes).count == changes.count else { throw DataProblem.invalid("重复单次改期") }
    }

    static func text(_ value: String, required: Bool = false) throws {
        guard value.utf8.count <= 16_384, !required || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DataProblem.invalid("文本长度或名称") }
    }
    static func strings(_ values: [String]) throws {
        guard values.count <= 1000 else { throw DataProblem.invalid("列表长度") }
        try values.forEach { try text($0) }
    }
    static func source(_ v: ContentSource) throws {
        try text(v.name, required: true)
        if let s = v.license { try text(s) }; if let s = v.reference { try text(s) }
    }
    static func number(_ value: Double?, min: Double = 0, max: Double) throws {
        if let value, !value.isFinite || value < min || value > max { throw DataProblem.invalid("数值范围") }
    }
    static func integer(_ value: Int?) throws {
        if let value, !(0...100_000).contains(value) { throw DataProblem.invalid("次数") }
    }
    static func nutrients(_ v: Nutrients) throws {
        try number(v.energyKcal, max: 100_000)
        for value in [v.proteinGrams, v.carbohydrateGrams, v.fatGrams] { try number(value, max: 100_000) }
    }
    static func moment(_ v: RecordMoment) throws {
        guard TimeZone(identifier: v.timeZoneID) != nil, v.instant.timeIntervalSince1970.isFinite,
              RecordMoment.day(v.instant, timeZoneID: v.timeZoneID) == v.localDate else { throw DataProblem.invalid("发生日期或时区") }
        try day(v.localDate)
    }
    static func day(_ v: String) throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = .gmt
        formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        guard v.count == 10, let date = formatter.date(from: v), formatter.string(from: date) == v else { throw DataProblem.invalid("归属日期") }
    }
    static func orders(_ values: [Int]) throws {
        guard Set(values).count == values.count, values.allSatisfy({ $0 >= 0 && $0 < maximumRecords }) else { throw DataProblem.invalid("排序") }
    }
    private static func supersets(_ values: [(UUID?, UUID)], kinds records: [BusinessRecord]) throws {
        let groups = Dictionary(grouping: values.filter { $0.0 != nil }, by: { $0.0! })
        let allowed = Set(records.compactMap { record -> UUID? in
            if case .exercise(let e) = record, [.externalLoad, .bodyweight, .assistedLoad].contains(e.measurement) { return e.stamp.id }
            return nil
        })
        guard groups.values.allSatisfy({ $0.count == 2 && $0.allSatisfy { allowed.contains($0.1) } }) else { throw DataProblem.invalid("超级组") }
    }
}
