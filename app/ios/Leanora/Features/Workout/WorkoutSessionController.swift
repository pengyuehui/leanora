import Foundation
import Observation

@MainActor @Observable final class WorkoutSessionController {
    let training: TrainingStore
    init(training: TrainingStore) { self.training = training }
    func change(_ session: WorkoutSession, _ edit: (inout WorkoutSession) throws -> Void) async -> Bool {
        do {
            var value = session; try edit(&value)
            return await training.run { [repository = training.repository, value] in try await repository.saveWorkout(value) } != nil
        } catch { training.error = error.localizedDescription; return false }
    }
}
