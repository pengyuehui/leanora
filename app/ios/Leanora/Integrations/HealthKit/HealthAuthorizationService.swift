import HealthKit
import Observation

enum HealthCategory: String, CaseIterable, Identifiable {
    case body, workouts, nutrition, activity
    var id: Self { self }
    var title: String {
        switch self {
        case .body: "身体数据"
        case .workouts: "训练"
        case .nutrition: "饮食营养"
        case .activity: "日常活动"
        }
    }
    var detail: String {
        switch self {
        case .body: "体重、体脂率"
        case .workouts: "训练摘要与运动时长"
        case .nutrition: "热量、蛋白质、脂肪、碳水"
        case .activity: "步数、活动能量 · 只读"
        }
    }
    var types: Set<HKSampleType> {
        if self == .workouts { return [HKObjectType.workoutType()] }
        let identifiers: [HKQuantityTypeIdentifier]
        switch self {
        case .body: identifiers = [.bodyMass, .bodyFatPercentage]
        case .nutrition: identifiers = [.dietaryEnergyConsumed, .dietaryProtein, .dietaryFatTotal, .dietaryCarbohydrates]
        case .activity: identifiers = [.stepCount, .activeEnergyBurned]
        case .workouts: identifiers = []
        }
        return Set(identifiers.compactMap { HKQuantityType.quantityType(forIdentifier: $0) })
    }
}

struct HealthAccessSelection {
    var reading: Set<HealthCategory> = [.body, .workouts]
    var writing: Set<HealthCategory> = []
    var readTypes: Set<HKObjectType> { Set(reading.flatMap(\.types).map { $0 as HKObjectType }) }
    var writeTypes: Set<HKSampleType> { Set(writing.filter { $0 != .activity }.flatMap(\.types)) }
    var isEmpty: Bool { readTypes.isEmpty && writeTypes.isEmpty }
}

@MainActor
protocol HealthAuthorizing {
    var isAvailable: Bool { get }
    func request(_ selection: HealthAccessSelection) async throws
    func writableCount(_ selection: HealthAccessSelection) -> Int
}

@MainActor
final class SystemHealthAuthorizer: HealthAuthorizing {
    private let store = HKHealthStore()
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    func request(_ selection: HealthAccessSelection) async throws {
        try await store.requestAuthorization(toShare: selection.writeTypes, read: selection.readTypes)
    }
    func writableCount(_ selection: HealthAccessSelection) -> Int {
        selection.writeTypes.filter { store.authorizationStatus(for: $0) == .sharingAuthorized }.count
    }
}

enum HealthAccessState: Equatable {
    case idle, requesting, processed(writable: Int, requested: Int), failed
}

@MainActor @Observable
final class HealthAuthorizationService {
    private let authorizer: any HealthAuthorizing
    private var processedSelection: HealthAccessSelection?
    private(set) var state: HealthAccessState = .idle
    var isAvailable: Bool { authorizer.isAvailable }
    var isRequesting: Bool { state == .requesting }

    init(authorizer: any HealthAuthorizing = SystemHealthAuthorizer()) { self.authorizer = authorizer }

    @discardableResult
    func request(_ selection: HealthAccessSelection) async -> Bool {
        guard isAvailable, !selection.isEmpty, !isRequesting else { return false }
        state = .requesting
        do {
            try await authorizer.request(selection)
            processedSelection = selection
            state = .processed(writable: authorizer.writableCount(selection), requested: selection.writeTypes.count)
            return true
        } catch {
            state = .failed
            return false
        }
    }

    func refreshWriteAccess() {
        guard case .processed = state, let selection = processedSelection else { return }
        state = .processed(writable: authorizer.writableCount(selection), requested: selection.writeTypes.count)
    }
}
