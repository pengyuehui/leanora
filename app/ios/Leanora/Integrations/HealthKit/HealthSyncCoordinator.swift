#if os(iOS)
import Foundation
import Observation

@MainActor @Observable final class HealthSyncCoordinator {
    let repository: AppModelActor
    private let transport: any HealthTransport
    private let engine: HealthSyncEngine
    private let observer = HealthObserverCoordinator()
    private(set) var configuration = HealthSyncConfiguration()
    private(set) var metadata: [HealthRuntimeRecord] = []
    private(set) var cache: [HealthRuntimeRecord] = []
    private(set) var cachedCount = 0
    private(set) var activity: HealthDailyActivity?
    private(set) var busy = false
    var error: String?
    private var operation: Task<Void, Never>?
    private var refreshGeneration = 0
    var jobs: [HealthWriteJob] { metadata.compactMap { if case .job(let v) = $0 { return v }; return nil } }
    var needsReconciliation: Bool { metadata.contains(.reconciliationRequired(true)) }
    var check: HealthCheck? { metadata.compactMap { if case .check(let v) = $0 { return v }; return nil }.first }

    init(repository: AppModelActor, transport: any HealthTransport = SystemHealthTransport()) {
        self.repository = repository; self.transport = transport; engine = HealthSyncEngine(repository: repository, transport: transport)
    }
    func refresh() async {
        refreshGeneration += 1; let generation = refreshGeneration
        do {
            let state = try await repository.healthDashboard(day: RecordMoment().localDate, timeZoneID: TimeZone.current.identifier)
            guard generation == refreshGeneration else { return }
            configuration = state.configuration; metadata = state.metadata; cache = state.cache; cachedCount = state.count; activity = state.activity
        } catch { self.error = "健康缓存暂不可用，请解锁后重试。" }
    }
    @discardableResult func configure(_ value: HealthSyncConfiguration) async -> Bool {
        error = nil
        do { try await repository.configureHealth(value); configuration = value; observe(); await refresh(); return true }
        catch { self.error = "同步设置未保存，请重试。"; return false }
    }
    func sync() async {
        guard !busy else { await engine.run(); return }; busy = true; defer { busy = false; operation = nil }
        observe()
        let engine = engine
        let task = Task { await engine.run() }; operation = task
        await task.value; await refresh()
    }
    func reconcile() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        error = nil
        do { try await HealthExportService(repository: repository, transport: transport).reconcile(); await refresh() }
        catch { self.error = "核对未完成，恢复资料仍不会自动导出。请检查健康读取访问后重试。" }
    }
    func exportHistory() async {
        error = nil
        do { try await repository.enqueueHealthHistory(); await sync() }
        catch { self.error = "请先开启同步并完成恢复核对。" }
    }
    @discardableResult func stop() async -> Bool {
        var config = configuration; config.enabled = false
        guard await configure(config) else { return false }; observer.stop()
        // Already-started writes are allowed to finish before a cleanup/reset.
        await operation?.value
        await engine.waitUntilIdle()
        return true
    }
    func clearCache() async {
        error = nil
        guard await stop() else { return }
        do { try await repository.clearHealthCache(); await refresh() }
        catch { self.error = "缓存尚未清除，请重试。" }
    }
    func deleteHealthCopies() async {
        guard !busy else { return }
        error = nil
        guard await stop() else { return }; busy = true; defer { busy = false }
        do {
            // Suppress first, even if only some types can be deleted. A later
            // edit must not recreate a component removed during partial cleanup.
            try await repository.markOwnHealthCopiesRemoved(completed: false)
            try await transport.deleteAllOwn()
            // Re-read bounded history on the next deliberate connection.
            try await repository.markOwnHealthCopiesRemoved()
            try await repository.purgeOwnHealthCache(source: transport.sourceBundleID); await refresh()
        } catch { self.error = "部分健康副本可能尚未移除，请检查写入权限并重试。其他来源的数据不会受影响。" }
    }
    func loadMore() async {
        do { cache += try await repository.healthCachePage(offset: cache.count); }
        catch { self.error = "健康摘要暂未加载，请重试。" }
    }
    func hide(_ value: HealthSampleValue) async {
        do { try await repository.hideHealthSample(value); await refresh() }
        catch { self.error = "隐藏未保存，请重试。" }
    }
    private func observe() {
        observer.start(configuration: configuration, engine: engine) { [weak self] in await self?.refresh() }
    }
}
#endif
