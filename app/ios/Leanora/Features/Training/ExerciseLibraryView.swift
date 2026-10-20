import SwiftUI

struct ExerciseLibraryView: View {
    @Environment(TrainingStore.self) private var training
    @State private var search = ""
    @State private var muscle = ""
    @State private var equipment = ""
    @State private var archived = false
    @State private var creating = false
    var onSelect: ((Exercise) -> Void)?
    private var results: [Exercise] { ExerciseSearch.filter(training.exercises, query: search, muscle: muscle.isEmpty ? nil : muscle, equipment: equipment.isEmpty ? nil : equipment, archived: archived) }
    var body: some View {
        List {
            TrainingErrorNotice()
            Section("筛选") {
                Picker("肌群", selection: $muscle) {
                    Text("全部肌群").tag("")
                    ForEach(Array(Set(training.exercises.flatMap(\.muscles))).sorted(), id: \.self) { Text($0).tag($0) }
                }.accessibilityIdentifier("exercise.muscle")
                Picker("器械", selection: $equipment) {
                    Text("全部器械").tag("")
                    ForEach(Array(Set(training.exercises.map(\.equipment))).filter { !$0.isEmpty }.sorted(), id: \.self) { Text($0).tag($0) }
                }.accessibilityIdentifier("exercise.equipment")
                if onSelect == nil { Toggle("查看已归档动作", isOn: $archived).accessibilityIdentifier("exercise.archived") }
            }
            Section {
                Button { creating = true } label: { Label("新建自定义动作", systemImage: "plus") }.accessibilityIdentifier("exercise.new")
                if results.isEmpty { ContentUnavailableView("没有匹配动作", systemImage: "magnifyingglass", description: Text("调整筛选条件，或创建自己的动作。")) }
                ForEach(results) { exercise in
                    if let onSelect {
                        Button { onSelect(exercise) } label: { row(exercise) }.accessibilityIdentifier("exercise.select.\(exercise.name)")
                    } else {
                        NavigationLink { ExerciseDetailView(exerciseID: exercise.id) } label: { row(exercise) }.accessibilityIdentifier("exercise.row.\(exercise.name)")
                    }
                }
            } header: { Text("\(results.count) 个动作") } footer: { Text("基础目录由 Leanora 独立整理。未提供动作教学或第三方图片；每个条目可查看来源。") }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索名称或别名")
        .navigationTitle(onSelect == nil ? "动作库" : "选择动作").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .sheet(isPresented: $creating) { NavigationStack { CustomExerciseEditor(exercise: Exercise(name: "")) } }
    }
    private func row(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(exercise.name).font(.headline)
            Text("\(exercise.equipment) · \(exercise.measurement.title)").font(.subheadline).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}

struct ExerciseDetailView: View {
    let exerciseID: UUID
    @Environment(TrainingStore.self) private var training
    @State private var editing = false
    @State private var confirmingArchive = false
    var body: some View {
        List {
            TrainingErrorNotice()
            if let exercise = training.exercise(exerciseID) {
                Section {
                    Text(exercise.name).font(.title2.weight(.semibold))
                    LabeledContent("记录类型", value: exercise.measurement.title)
                    LabeledContent("器械", value: exercise.equipment)
                    LabeledContent("肌群", value: exercise.muscles.joined(separator: "、"))
                    if !exercise.aliases.isEmpty { Text("别名：\(exercise.aliases.joined(separator: "、"))") }
                }
                Section("内容来源") {
                    Text(exercise.source.name).accessibilityIdentifier("exercise.source")
                    if let license = exercise.source.license { Text(license).foregroundStyle(.secondary) }
                    if let reference = exercise.source.reference { Text(reference).font(.caption).textSelection(.enabled) }
                }
                Section {
                    if !training.catalog.contains(where: { $0.stamp.id == exerciseID }) {
                        Button("编辑自定义动作") { editing = true }.accessibilityIdentifier("exercise.edit")
                    }
                    Button(exercise.isArchived ? "恢复动作" : "归档动作") { confirmingArchive = true }.accessibilityIdentifier("exercise.archive")
                    Text("归档后不出现在默认动作库；已有模板与训练历史会保留。").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("动作详情").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .sheet(isPresented: $editing) { if let exercise = training.exercise(exerciseID) { NavigationStack { CustomExerciseEditor(exercise: exercise) } } }
        .confirmationDialog("更改动作归档状态？", isPresented: $confirmingArchive, titleVisibility: .visible) {
            if let exercise = training.exercise(exerciseID) {
                Button(exercise.isArchived ? "恢复动作" : "归档动作") {
                    Task { _ = await training.run { [repository = training.repository, catalog = training.catalog] in try await repository.setExerciseArchived(exerciseID, archived: !exercise.isArchived, catalog: catalog) } }
                }.accessibilityIdentifier("exercise.confirmArchive")
            }
        }
    }
}

struct CustomExerciseEditor: View {
    @Environment(TrainingStore.self) private var training
    @Environment(\.dismiss) private var dismiss
    @State private var value: Exercise
    @State private var aliases: String
    @State private var muscles: String
    init(exercise: Exercise) {
        _value = State(initialValue: exercise); _aliases = State(initialValue: exercise.aliases.joined(separator: "、")); _muscles = State(initialValue: exercise.muscles.joined(separator: "、"))
    }
    var body: some View {
        Form {
            TrainingErrorNotice()
            Section("动作资料") {
                TextField("动作名称", text: $value.name).accessibilityIdentifier("exercise.name")
                TextField("别名，以顿号分隔", text: $aliases)
                Picker("记录类型", selection: $value.measurement) { ForEach(ExerciseMeasurement.allCases, id: \.self) { Text($0.title).tag($0) } }
                TextField("器械", text: $value.equipment).accessibilityIdentifier("exercise.customEquipment")
                TextField("肌群，以顿号分隔", text: $muscles)
            }
            Section { Text("自定义内容由你创建；修改资料不会改写已保存的训练快照。").foregroundStyle(.secondary) }
        }
        .navigationTitle("自定义动作").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    var draft = value
                    draft.aliases = aliases.components(separatedBy: "、").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    draft.muscles = muscles.components(separatedBy: "、").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    Task { if await training.run({ [repository = training.repository, catalog = training.catalog, draft] in try await repository.saveCustomExercise(draft, catalog: catalog) }) != nil { dismiss() } }
                }.disabled(training.busy || value.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("exercise.save")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .disabled(training.busy)
    }
}
