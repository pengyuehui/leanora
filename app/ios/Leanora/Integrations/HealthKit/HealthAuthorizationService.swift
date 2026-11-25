import HealthKit
import Observation
#if os(iOS)
import UIKit
#endif

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
    var applicationState: String { get }
    func promptStatus(_ selection: HealthAccessSelection) async -> HealthPromptStatus
    func request(_ selection: HealthAccessSelection) async throws
    func writableCount(_ selection: HealthAccessSelection) -> Int
}

extension HealthAuthorizing {
    var applicationState: String { "active" }
    func promptStatus(_ selection: HealthAccessSelection) async -> HealthPromptStatus { .unknown }
}

@MainActor
final class SystemHealthAuthorizer: HealthAuthorizing {
    private let store = HKHealthStore()
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    var applicationState: String {
        #if os(iOS)
        switch UIApplication.shared.applicationState {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "unknown"
        }
        #else
        "active"
        #endif
    }
    func promptStatus(_ selection: HealthAccessSelection) async -> HealthPromptStatus {
        guard let status = try? await store.statusForAuthorizationRequest(toShare: selection.writeTypes, read: selection.readTypes) else { return .unknown }
        switch status {
        case .shouldRequest: return .shouldRequest
        case .unnecessary: return .unnecessary
        default: return .unknown
        }
    }
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
    private(set) var diagnostic: HealthAuthorizationDiagnostic?
    var isAvailable: Bool { authorizer.isAvailable }
    var isRequesting: Bool { state == .requesting }

    init(authorizer: any HealthAuthorizing = SystemHealthAuthorizer()) { self.authorizer = authorizer }

    @discardableResult
    func request(_ selection: HealthAccessSelection) async -> Bool {
        guard !isRequesting else { return false }
        failureMessage = nil; failureCode = nil
        diagnostic = HealthAuthorizationDiagnostic(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            applicationState: authorizer.applicationState,
            reading: selection.readTypes.map(\.identifier).sorted(), writing: selection.writeTypes.map(\.identifier).sorted())
        guard isAvailable else { return reject("此设备的健康数据暂不可用。", code: "HealthUnavailable") }
        guard !selection.isEmpty else { return reject("请先选择至少一种访问范围。", code: "EmptySelection") }
        guard authorizer.applicationState == "active" else { return reject("请回到 App 前台并解锁设备后重试。", code: "ApplicationNotActive") }
        state = .requesting
        diagnostic?.promptStatus = await authorizer.promptStatus(selection)
        diagnostic?.applicationState = authorizer.applicationState
        guard authorizer.applicationState == "active" else { return reject("请回到 App 前台并解锁设备后重试。", code: "ApplicationNotActive") }
        do {
            try await authorizer.request(selection)
            processedSelection = selection
            state = .processed(writable: authorizer.writableCount(selection), requested: selection.writeTypes.count)
            diagnostic?.outcome = "processed"
            diagnostic?.writableCount = authorizer.writableCount(selection)
            return true
        } catch {
            let problem = error as NSError
            failureCode = "\(problem.domain) (\(problem.code))"
            diagnostic?.outcome = "failed"; diagnostic?.errorCode = failureCode
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

    private func reject(_ message: String, code: String) -> Bool {
        failureMessage = message; failureCode = code; state = .failed
        diagnostic?.outcome = "notRequested"; diagnostic?.errorCode = code
        return false
    }

    func refreshWriteAccess() {
        guard case .processed = state, let selection = processedSelection else { return }
        state = .processed(writable: authorizer.writableCount(selection), requested: selection.writeTypes.count)
        diagnostic?.writableCount = authorizer.writableCount(selection)
    }
}
