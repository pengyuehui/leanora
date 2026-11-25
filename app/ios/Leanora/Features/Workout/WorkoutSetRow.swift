import SwiftUI

enum WorkoutInputColumn: String, Hashable { case load, repetitions, duration, distance }
struct WorkoutInputFocus: Hashable {
    let setID: UUID
    let column: WorkoutInputColumn
}

struct WorkoutSetRow: View {
    let exercise: SessionExercise
    let set: WorkoutSet
    let index: Int
    let exerciseIndex: Int
    @Binding var input: WorkoutSetInput
    let focused: FocusState<WorkoutInputFocus?>.Binding
    let enabled: Bool
    let dirty: Bool
    let error: String?
    let previous: String?
    let onComplete: () -> Void
    let onAdvanced: () -> Void
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if set.completedAt != nil {
                HStack {
                    groupLabel
                    Text(summary).font(.body.monospacedDigit()).frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(LeanoraTheme.accent).accessibilityLabel("已完成")
                    advanced
                }
            } else if typeSize.isAccessibilitySize {
                HStack { groupLabel; Spacer(); advanced; complete }
                fields
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    groupLabel
                    fields
                    complete
                    advanced
                }
            }
            if let previous { Text(previous).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("workout.previousSet.\(exerciseIndex).\(index)") }
            if dirty && set.completedAt == nil { Text("未保存").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("workout.unsaved.\(exerciseIndex).\(index)") }
            if let error {
                Label(error, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.red)
                    .accessibilityIdentifier("workout.rowError.\(exerciseIndex).\(index)")
            }
        }.padding(.vertical, 5)
    }
    private var groupLabel: some View {
        VStack(spacing: 4) {
            Text("\(index + 1)").font(.headline.monospacedDigit())
            Text(set.kind == .working ? "组" : set.kind.title).font(.caption2).foregroundStyle(.secondary)
        }.frame(minWidth: 25, minHeight: 44)
    }
    private var fields: some View {
        HStack(spacing: 8) {
            if [.externalLoad, .assistedLoad].contains(exercise.snapshot.measurement) { field(preferences.values.weightUnit.rawValue, $input.load, .load) }
            if [.externalLoad, .bodyweight, .assistedLoad].contains(exercise.snapshot.measurement) { field("次数", $input.repetitions, .repetitions) }
            if [.duration, .cardio].contains(exercise.snapshot.measurement) { field("秒", $input.duration, .duration).disabled(set.timerStartedAt != nil) }
            if exercise.snapshot.measurement == .cardio { field(preferences.values.distanceUnit.rawValue, $input.distance, .distance) }
        }
    }
    private func field(_ title: String, _ value: Binding<String>, _ column: WorkoutInputColumn) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField("—", text: value)
                .keyboardType(column == .repetitions ? .numberPad : .decimalPad)
                .textFieldStyle(.roundedBorder).multilineTextAlignment(.center).monospacedDigit()
                .frame(minHeight: 44).disabled(!enabled)
                .focused(focused, equals: WorkoutInputFocus(setID: set.id, column: column))
                .accessibilityLabel("\(exercise.snapshot.name)，第 \(index + 1) 组，\(title)")
                .accessibilityIdentifier("workout.input.\(exerciseIndex).\(index).\(column.rawValue)")
        }.frame(maxWidth: .infinity)
    }
    private var complete: some View {
        Button(action: onComplete) { Image(systemName: "checkmark.circle").font(.title2).frame(minWidth: 44, minHeight: 44) }
            .buttonStyle(.borderless).disabled(!enabled)
            .accessibilityLabel("完成第 \(index + 1) 组").accessibilityIdentifier("workout.complete.\(exerciseIndex).\(index)")
    }
    private var advanced: some View {
        Button(action: onAdvanced) { Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44) }
            .buttonStyle(.borderless).accessibilityLabel("编辑第 \(index + 1) 组的类型与强度")
            .accessibilityIdentifier("workout.set.\(exerciseIndex).\(index)")
    }
    private var summary: String {
        switch exercise.snapshot.measurement {
        case .externalLoad, .assistedLoad: "\(input.load) \(preferences.values.weightUnit.rawValue) × \(input.repetitions) 次"
        case .bodyweight: "\(input.repetitions) 次"
        case .duration: "\(input.duration) 秒"
        case .cardio: "\(input.duration) 秒 · \(input.distance.isEmpty ? "—" : input.distance) \(preferences.values.distanceUnit.rawValue)"
        }
    }
}
