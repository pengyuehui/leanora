import Foundation
import Observation

enum WeightUnit: String, CaseIterable, Codable, Identifiable {
    case kilograms = "kg"
    case pounds = "lb"
    var id: Self { self }
    var title: String { self == .kilograms ? "公斤 · kg" : "磅 · lb" }
}

enum DistanceUnit: String, CaseIterable, Codable, Identifiable {
    case kilometers = "km"
    case miles = "mi"
    var id: Self { self }
    var title: String { self == .kilometers ? "公里 · km" : "英里 · mi" }
}

struct PreferenceValues: Codable, Equatable {
    var weightUnit: WeightUnit = .kilograms
    var distanceUnit: DistanceUnit = .kilometers
    var weeklyTrainingDays: Int? = nil
    var dailyEnergyGoal: Int? = nil
}

enum PreferenceValidationError: LocalizedError {
    case invalidEnergy, invalidTrainingDays
    var errorDescription: String? {
        switch self {
        case .invalidEnergy: "热量目标请填写 1 至 20000 之间的整数，或留空。"
        case .invalidTrainingDays: "每周训练天数请选择 1 至 7 天，或暂不设置。"
        }
    }
}

@MainActor @Observable
final class AppPreferences {
    private let defaults: UserDefaults
    private(set) var values: PreferenceValues
    private(set) var hasCompletedOnboarding: Bool
    private(set) var lastHealthRequest: Date?
    private(set) var storageNotice: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: "onboarding.completed")
        lastHealthRequest = defaults.object(forKey: "health.lastRequest") as? Date
        if let data = defaults.data(forKey: "preferences.v1") {
            if let decoded = try? JSONDecoder().decode(PreferenceValues.self, from: data),
               (decoded.weeklyTrainingDays.map { (1...7).contains($0) } ?? true),
               (decoded.dailyEnergyGoal.map { (1...20000).contains($0) } ?? true) {
                values = decoded
            } else {
                values = .init()
                storageNotice = "偏好设置无法读取，请重新确认单位与目标。"
            }
        } else {
            values = .init()
        }
    }

    func save(weight: WeightUnit, distance: DistanceUnit, days: Int?, energyText: String) throws {
        let text = energyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let energy: Int?
        if text.isEmpty {
            energy = nil
        } else {
            guard text.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let number = Int(text), (1...20000).contains(number) else {
                throw PreferenceValidationError.invalidEnergy
            }
            energy = number
        }
        guard days.map({ (1...7).contains($0) }) ?? true else {
            throw PreferenceValidationError.invalidTrainingDays
        }
        let updated = PreferenceValues(weightUnit: weight, distanceUnit: distance,
                                       weeklyTrainingDays: days, dailyEnergyGoal: energy)
        let encoded = try JSONEncoder().encode(updated)
        defaults.set(encoded, forKey: "preferences.v1")
        values = updated
        storageNotice = nil
    }

    func finishOnboarding() {
        defaults.set(true, forKey: "onboarding.completed")
        hasCompletedOnboarding = true
    }

    func markHealthRequestProcessed() {
        let date = Date()
        defaults.set(date, forKey: "health.lastRequest")
        lastHealthRequest = date
    }
}
