import Foundation

struct TrainingTargetInput: Sendable {
    var minimum = ""
    var maximum = ""
    var load = ""
    var duration = ""
    var distance = ""
    var rest = "90"

    static func decimal(_ text: String) throws -> Double? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }
        guard value.range(of: "^[0-9]+([.,][0-9]+)?$", options: .regularExpression) != nil,
              let result = Double(value.replacingOccurrences(of: ",", with: ".")), result.isFinite else { throw TrainingProblem.invalidTargets }
        return result
    }
    static func integer(_ text: String) throws -> Int? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }
        guard value.allSatisfy({ $0.isASCII && $0.isNumber }), let result = Int(value) else { throw TrainingProblem.invalidTargets }
        return result
    }
    func applying(to item: TemplateItem, measurement: ExerciseMeasurement, pounds: Bool, miles: Bool) throws -> TemplateItem {
        var item = item
        item.minimumReps = nil; item.maximumReps = nil; item.loadKg = nil; item.durationSeconds = nil; item.distanceMeters = nil
        switch measurement {
        case .externalLoad, .bodyweight, .assistedLoad:
            item.minimumReps = try Self.integer(minimum); item.maximumReps = try Self.integer(maximum)
            if measurement != .bodyweight { item.loadKg = try Self.decimal(load).map { $0 * (pounds ? 0.45359237 : 1) } }
        case .duration: item.durationSeconds = try Self.decimal(duration)
        case .cardio:
            item.durationSeconds = try Self.decimal(duration)
            item.distanceMeters = try Self.decimal(distance).map { $0 * (miles ? 1609.344 : 1000) }
        }
        guard let rest = try Self.decimal(rest) else { throw TrainingProblem.invalidTargets }
        item.restSeconds = rest
        try DomainValidation.integer(item.minimumReps); try DomainValidation.integer(item.maximumReps)
        if let a = item.minimumReps, let b = item.maximumReps, a > b { throw DataProblem.invalid("次数范围") }
        try DomainValidation.number(item.loadKg, max: 5000); try DomainValidation.number(item.durationSeconds, max: 604800)
        try DomainValidation.number(item.distanceMeters, max: 10_000_000); try DomainValidation.number(item.restSeconds, max: 86400)
        return item
    }
}
