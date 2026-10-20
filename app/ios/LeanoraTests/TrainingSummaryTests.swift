import XCTest
@testable import Leanora

final class TrainingSummaryTests: XCTestCase {
    func testVolumeExcludesWarmupIncompleteOtherKindsAndOtherMeasurements() {
        let now = Date(); let e = Exercise(name: "卧推")
        let sets = [WorkoutSet(order: 0, loadKg: 20, repetitions: 10, completedAt: now),
                    WorkoutSet(order: 1, kind: .warmup, loadKg: 50, repetitions: 10, completedAt: now),
                    WorkoutSet(order: 2, loadKg: 100, repetitions: 10),
                    WorkoutSet(order: 3, kind: .drop, loadKg: 30, repetitions: 10, completedAt: now)]
        var session = WorkoutSession(endedAt: now, status: .completed, name: "测试", exercises: [SessionExercise(order: 0, snapshot: ExerciseSnapshot(e), sets: sets)])
        var assisted = session.exercises[0]; assisted.id = UUID(); assisted.snapshot.measurement = .assistedLoad; session.exercises.append(assisted)
        let summary = TrainingSummary(sessions: [session]); XCTAssertEqual(summary.volumeKg, 200); XCTAssertEqual(summary.personalRecords[e.stamp.id], 20)
        session.status = .active; XCTAssertEqual(TrainingSummary(sessions: [session]).workouts, 0)
        session.status = .abandoned; XCTAssertEqual(TrainingSummary(sessions: [session]).volumeKg, 0)
    }
    func testPRRecalculatesAfterSourceSetEditedOrRemoved() {
        let e = Exercise(name: "测试"), now = Date()
        var s = WorkoutSession(endedAt: now, status: .completed, name: "测试", exercises: [SessionExercise(order: 0, snapshot: ExerciseSnapshot(e), sets: [WorkoutSet(order: 0, loadKg: 60, repetitions: 3, completedAt: now), WorkoutSet(order: 1, loadKg: 40, repetitions: 10, completedAt: now)])])
        XCTAssertEqual(TrainingSummary(sessions: [s]).personalRecords[e.stamp.id], 60)
        s.exercises[0].sets[0].loadKg = 30; XCTAssertEqual(TrainingSummary(sessions: [s]).personalRecords[e.stamp.id], 40)
        s.exercises[0].sets.remove(at: 1); XCTAssertEqual(TrainingSummary(sessions: [s]).personalRecords[e.stamp.id], 30)
        s.stamp.deletedAt = now; XCTAssertTrue(TrainingSummary(sessions: [s]).personalRecords.isEmpty)
    }
}
