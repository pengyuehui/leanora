import XCTest
@testable import Leanora

final class ExerciseProgressTests: XCTestCase {
    private func session(_ exercise: Exercise, at date: Date, sets: [WorkoutSet]) -> WorkoutSession {
        WorkoutSession(started: RecordMoment(date), endedAt: date.addingTimeInterval(60), status: .completed, name: "训练", exercises: [
            SessionExercise(order: 0, snapshot: ExerciseSnapshot(exercise), sets: sets)])
    }
    func testMergesRepeatedExerciseAndExcludesWarmupIncompleteDeletedAndWrongType() throws {
        let exercise = Exercise(name: "推举"), date = DataFixtures.date
        let working = WorkoutSet(order: 1, loadKg: 20, repetitions: 8, completedAt: date)
        var value = session(exercise, at: date, sets: [WorkoutSet(order: 0, kind: .warmup, loadKg: 100, repetitions: 10, completedAt: date), working, WorkoutSet(order: 2, loadKg: 99, repetitions: 10)])
        value.exercises.append(SessionExercise(order: 1, snapshot: ExerciseSnapshot(exercise), sets: [WorkoutSet(order: 0, loadKg: 25, repetitions: 4, completedAt: date)]))
        var abandoned = value; abandoned.stamp = RecordStamp(); abandoned.status = .abandoned
        var deleted = value; deleted.stamp = RecordStamp(); deleted.stamp.deletedAt = date
        var changed = exercise; changed.measurement = .bodyweight
        let wrong = session(changed, at: date, sets: [working])
        let history = ExerciseProgress.history(exerciseID: exercise.stamp.id, measurement: .externalLoad, sessions: [abandoned,deleted,wrong,value])
        XCTAssertEqual(history.count, 1)
        let row = try XCTUnwrap(history.first)
        XCTAssertEqual(row.sets.count, 2); XCTAssertEqual(row.volumeKg, 260); XCTAssertEqual(row.bestLoadKg, 25)
        XCTAssertEqual(row.repetitions, 12); XCTAssertEqual(row.exercises.count, 2)
        XCTAssertEqual(value.exercises[0].sets.count, 3)
    }
    func testDifferentMeasurementKindsNeverCreateFalseLoadPRs() throws {
        let date = DataFixtures.date
        for measurement in [ExerciseMeasurement.bodyweight, .assistedLoad, .duration, .cardio] {
            let exercise = Exercise(name: "动作", measurement: measurement)
            let value = session(exercise, at: date, sets: [WorkoutSet(order: 0, loadKg: 20, repetitions: 8, durationSeconds: 60, distanceMeters: 100, completedAt: date)])
            let row = try XCTUnwrap(ExerciseProgress.history(exerciseID: exercise.stamp.id, measurement: measurement, sessions: [value]).first)
            XCTAssertNil(row.volumeKg); XCTAssertNil(row.bestLoadKg)
            XCTAssertEqual(row.repetitions, 8); XCTAssertEqual(row.duration, 60); XCTAssertEqual(row.distance, 100)
        }
    }
    func testHistoryIsNewestFirstAndRecomputesAfterSourceEditOrDelete() {
        let exercise = Exercise(name: "动作"), date = DataFixtures.date
        let set = WorkoutSet(order: 0, loadKg: 10, repetitions: 10, completedAt: date)
        let old = session(exercise, at: date, sets: [set])
        var new = session(exercise, at: date.addingTimeInterval(86400), sets: [set])
        new.exercises[0].sets[0].loadKg = 20
        var rows = ExerciseProgress.history(exerciseID: exercise.stamp.id, measurement: .externalLoad, sessions: [old,new])
        XCTAssertEqual(rows.map(\.id), [new.stamp.id,old.stamp.id]); XCTAssertEqual(rows[0].volumeKg! - rows[1].volumeKg!, 100)
        new.stamp.deletedAt = date
        rows = ExerciseProgress.history(exerciseID: exercise.stamp.id, measurement: .externalLoad, sessions: [old,new])
        XCTAssertEqual(rows.count, 1)
    }
}
