import XCTest
@testable import Leanora

final class CapacityTests: XCTestCase, @unchecked Sendable {
    func testTenThousandSetsAndDietRecordsQueryAndCSV() async throws {
        guard ProcessInfo.processInfo.environment["LEANORA_SCALE_TESTS"] == "1" else { throw XCTSkip("Run with LEANORA_SCALE_TESTS=1 for capacity evidence") }
        let repository = AppModelActor(modelContainer: try StoreFactory.memory())
        let exercise = Exercise(name: "容量测试")
        let moment = RecordMoment()
        let sessions = (0..<100).map { _ -> BusinessRecord in
            let sets = (0..<100).map { WorkoutSet(order: $0, loadKg: 20, repetitions: 10, completedAt: moment.instant) }
            return .session(WorkoutSession(started: moment, endedAt: moment.instant.addingTimeInterval(600), status: .completed, name: "历史", exercises: [SessionExercise(order: 0, snapshot: ExerciseSnapshot(exercise), sets: sets)]))
        }
        let diets = (0..<10_000).map { _ in BusinessRecord.diet(DietEntry(occurred: moment, meal: .lunch, nutrients: Nutrients(energyKcal: 100))) }
        try await repository.save([.profile(LocalProfile()), .exercise(exercise)] + sessions + diets)
        var times: [Double] = []
        for _ in 0..<5 {
            let start = Date(); let records = try await repository.snapshot(); times.append(Date().timeIntervalSince(start))
            XCTAssertEqual(records.filter { $0.kind == "diet" }.count, 10_000)
            let all = records.compactMap { if case .session(let v) = $0 { return v }; return nil }
            XCTAssertEqual(TrainingSummary(sessions: all).volumeKg, 2_000_000)
        }
        let data = try await repository.exportCSV(); XCTAssertGreaterThan(data.count, 1_000_000)
        print("CAPACITY business records=10102 sets=10000 diets=10000 query_seconds=\(times) csv_bytes=\(data.count)")
    }
    func testHundredThousandHealthSamplesPagedOffMainThread() async throws {
        guard ProcessInfo.processInfo.environment["LEANORA_SCALE_TESTS"] == "1" else { throw XCTSkip("Run with LEANORA_SCALE_TESTS=1 for capacity evidence") }
        let repository = try await HealthFixtures.repository(reading: [.weight]), transport = HealthTestTransport()
        await transport.seed((0..<100_000).map { _ in HealthFixtures.sample() })
        let config = try await repository.healthConfiguration(), start = Date()
        let probe = Task.detached { () -> [Double] in
            var latencies: [Double] = []
            while !Task.isCancelled {
                let started = Date(); await MainActor.run {}; latencies.append(Date().timeIntervalSince(started))
                do { try await Task.sleep(for: .milliseconds(20)) } catch { break }
            }
            return latencies
        }
        let importing = Task.detached { try await HealthImportService(repository: repository, transport: transport).run(configuration: config) }
        do { try await importing.value } catch { probe.cancel(); throw error }
        probe.cancel()
        let latencies = await probe.value.sorted(), p95 = latencies[min(latencies.count - 1, Int(Double(latencies.count) * 0.95))]
        let count = try await repository.healthCacheCount(), page = try await repository.healthCachePage()
        XCTAssertEqual(count, 100_000); XCTAssertEqual(page.count, 100)
        let stats = await transport.counts(); XCTAssertEqual(stats.pages, 200)
        XCTAssertGreaterThan(latencies.count, 10); XCTAssertLessThan(p95, 0.3)
        print("CAPACITY health=100000 page_size=500 elapsed_seconds=\(Date().timeIntervalSince(start)) main_actor_probes=\(latencies.count) p95_seconds=\(p95) max_seconds=\(latencies.last ?? 0)")
    }
}
