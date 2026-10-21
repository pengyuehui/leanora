import Foundation

actor HealthSyncEngine {
    let repository: AppModelActor
    let transport: any HealthTransport
    private var running = false
    private var rerunRequested = false
    private var idleWaiters: [CheckedContinuation<Void, Never>] = []
    init(repository: AppModelActor, transport: any HealthTransport) { self.repository = repository; self.transport = transport }
    func run() async {
        if running { rerunRequested = true; return }
        running = true
        repeat {
            rerunRequested = false
            await checkOnce()
        } while rerunRequested
        running = false
        let waiters = idleWaiters; idleWaiters = []
        for waiter in waiters { waiter.resume() }
    }
    func waitUntilIdle() async {
        guard running else { return }
        await withCheckedContinuation { idleWaiters.append($0) }
    }
    private func checkOnce() async {
        do {
            let config = try await repository.healthConfiguration()
            guard config.enabled else {
                // An explicit per-record delete is allowed with automatic sync
                // stopped. It still uses a durable, permission-checked job.
                try await HealthExportService(repository: repository, transport: transport).run()
                return
            }
            var check: HealthCheck = if case .check(let old) = try await repository.healthRuntimeValue("health:check") { old } else { HealthCheck() }
            check.attemptedAt = Date(); check.retryNeeded = true
            try await repository.recordHealthCheck(check)
            do {
                try await HealthImportService(repository: repository, transport: transport).run(configuration: config)
                // Import first: detect a Health-side removal before draining writes.
                try await HealthExportService(repository: repository, transport: transport).run()
                check.succeededAt = Date(); check.retryNeeded = false; check.message = nil
            } catch {
                check.message = "暂未完成健康检查，已有记录保留；解锁后或下次打开时重试。"
            }
            if try await repository.healthConfiguration().enabled { try await repository.recordHealthCheck(check) }
        } catch { /* Durable cursor/jobs remain untouched; next foreground retries. */ }
    }
}
