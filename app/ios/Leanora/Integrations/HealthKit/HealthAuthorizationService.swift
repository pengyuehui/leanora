import HealthKit
import Observation

enum HealthCategory: String, CaseIterable, Identifiable {
    case body, workouts, nutrition, activity
    var id: Self { self }
    var components: Set<HealthComponent> {
        switch self {
        case .body: [.weight, .bodyFat]
        case .workouts: [.workout]
        case .nutrition: [.energy, .protein, .carbohydrate, .fat]
        case .activity: []
        }
    }
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

extension HealthAccessSelection {
    init(configuration: HealthSyncConfiguration) {
        self.init(reading: Set(HealthCategory.allCases.filter {
            !$0.components.isDisjoint(with: configuration.reading) || ($0 == .activity && configuration.readActivity)
        }), writing: Set(HealthCategory.allCases.filter { !$0.components.isDisjoint(with: configuration.writing) }))
    }
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
    private(set) var failureMessage: String?
    private(set) var failureCode: String?
    var isAvailable: Bool { authorizer.isAvailable }
    var isRequesting: Bool { state == .requesting }

    init(authorizer: any HealthAuthorizing = SystemHealthAuthorizer()) { self.authorizer = authorizer }

    @discardableResult
    func request(_ selection: HealthAccessSelection) async -> Bool {
        guard isAvailable, !selection.isEmpty, !isRequesting else { return false }
        failureMessage = nil; failureCode = nil
        state = .requesting
        do {
            try await authorizer.request(selection)
            processedSelection = selection
            state = .processed(writable: authorizer.writableCount(selection), requested: selection.writeTypes.count)
            return true
        } catch {
            let problem = error as NSError
            failureCode = "\(problem.domain) (\(problem.code))"
            if problem.domain == NSCocoaErrorDomain && problem.code == CocoaError.userCancelled.rawValue {
                failureMessage = "已取消系统授权，可以重试。"
            } else if problem.domain == HKErrorDomain && problem.code == HKError.Code.errorAuthorizationDenied.rawValue {
                failureMessage = "健康访问被限制，请在「健康」App 中检查 Leanora Fitness 的权限。"
            } else if problem.domain == HKErrorDomain && problem.code == HKError.Code.errorHealthDataUnavailable.rawValue {
                failureMessage = "此设备的健康数据暂不可用。"
            } else {
                failureMessage = "系统授权未完成，请解锁设备后重试。"
            }
            state = .failed
            return false
        }
    }

    func refreshWriteAccess() {
        guard case .processed = state, let selection = processedSelection else { return }
        state = .processed(writable: authorizer.writableCount(selection), requested: selection.writeTypes.count)
    }
}
