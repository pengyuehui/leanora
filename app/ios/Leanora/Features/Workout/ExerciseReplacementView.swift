import SwiftUI

struct ExerciseReplacementView: View {
    let session: WorkoutSession
    let source: SessionExercise
    let onSaved: () -> Void
    @Environment(TrainingStore.self) private var training
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var sameMeasurement = true
    @State private var matchMuscles = true
    @State private var equipment = ""
    @State private var selected: Exercise?

    private var sourceMuscles: Set<String> { Set(training.exercise(source.snapshot.exerciseID)?.muscles ?? []) }
    private var candidates: [Exercise] {
        training.exercises.filter { exercise in
            exercise.id != source.snapshot.exerciseID && !exercise.isArchived &&
            (!sameMeasurement || exercise.measurement == source.snapshot.measurement) &&
            (!matchMuscles || sourceMuscles.isEmpty || !sourceMuscles.isDisjoint(with: exercise.muscles)) &&
            (equipment.isEmpty || exercise.equipment == equipment) &&
            (query.isEmpty || ([exercise.name] + exercise.aliases).contains { $0.localizedCaseInsensitiveContains(query) })
        }
    }
    var body: some View {
        Group {
            if let selected { preview(selected) }
            else {
                List {
                    Section {
                        Toggle("相同记录类型", isOn: $sameMeasurement).accessibilityIdentifier("replacement.sameMeasurement")
                        Toggle("相同目标肌群", isOn: $matchMuscles).disabled(sourceMuscles.isEmpty)
                        Picker("器械", selection: $equipment) {
                            Text("全部").tag("")
                            ForEach(Set(training.exercises.map(\.equipment)).filter { !$0.isEmpty }.sorted(), id: \.self) { Text($0).tag($0) }
                        }
                    }
                    Section("\(candidates.count) 个动作") {
                        if candidates.isEmpty { ContentUnavailableView.search(text: query) }
                        ForEach(candidates) { exercise in
                            Button { self.selected = exercise } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name).foregroundStyle(.primary)
                                    if !exercise.equipment.isEmpty { Text(exercise.equipment).font(.caption).foregroundStyle(.secondary) }
                                }.frame(minHeight: 44)
                            }.accessibilityIdentifier("replacement.row.\(exercise.name)")
                        }
                    }
                }.searchable(text: $query, prompt: "搜索替换动作")
            }
        }.navigationTitle("替换 \(source.snapshot.name)").navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
            .disabled(training.busy)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.accessibilityIdentifier("replacement.cancel") }
            }
    }
    private func preview(_ replacement: Exercise) -> some View {
        Form {
            TrainingErrorNotice()
            if let value = try? ExerciseReplacement.preview(source, with: replacement) {
                Section("替换预览") {
                    LabeledContent("原动作", value: value.sourceName)
                    LabeledContent("新动作", value: value.replacementName)
                    LabeledContent("保留原动作完成组", value: "\(value.completedSets) 组").accessibilityIdentifier("replacement.completed")
                    LabeledContent("新动作待完成组", value: "\(value.pendingSets) 组")
                    Text(value.clearsTargets ? "记录类型不同，原目标将清空。" : "沿用计划目标，实际值留空。")
                    if value.unpairsSuperset { Text("本次超级组将解除配对。") }
                    Text("新动作需要重新填写实际值；原模板保持。")
                }
                Section {
                    Button("确认替换") {
                        Task {
                            if await training.run({ [repository = training.repository, catalog = training.catalog] in
                                try await repository.replaceWorkoutExercise(session.id, revision: session.stamp.revision, exerciseID: source.id, replacementID: replacement.id, catalog: catalog)
                            }) != nil { onSaved(); dismiss() }
                        }
                    }.accessibilityIdentifier("replacement.confirm")
                    Button("重新选择") { selected = nil }.accessibilityIdentifier("replacement.chooseAgain")
                }
            }
        }
    }
}
