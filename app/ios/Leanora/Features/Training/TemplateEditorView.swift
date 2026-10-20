import SwiftUI

struct TemplateEditorView: View {
    @Environment(TrainingStore.self) private var training
    @Environment(\.dismiss) private var dismiss
    let original: WorkoutTemplate
    @State private var draft: WorkoutTemplate
    @State private var choosing = false
    @State private var editingItem: TemplateItem?
    @State private var discarding = false
    @FocusState private var focused: Bool

    init(template: WorkoutTemplate) {
        var ordered = template; ordered.items.sort { $0.order < $1.order }
        original = ordered; _draft = State(initialValue: ordered)
    }

    var body: some View {
        Form {
            TrainingErrorNotice()
            Section("模板资料") {
                TextField("模板名称", text: $draft.name).focused($focused).submitLabel(.done).onSubmit { focused = false }.accessibilityIdentifier("template.name")
                TextField("备注（可选）", text: $draft.notes, axis: .vertical).focused($focused)
            }
            Section {
                ForEach(Array(draft.items.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        Button { focused = false; editingItem = item } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(index + 1). \(training.exercise(item.exerciseID)?.name ?? "动作不可用")")
                                Text("\(item.plannedSets) 组 · 休息 \(item.restSeconds.formatted()) 秒").font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain).accessibilityIdentifier("template.item.\(index)")
                        Menu {
                            Button("复制此动作") { var copy = item; copy.id = UUID(); copy.supersetID = nil; draft.items.insert(copy, at: index + 1) }
                            Button("上移") { draft.items.swapAt(index, index - 1) }.disabled(index == 0)
                            Button("下移") { draft.items.swapAt(index, index + 1) }.disabled(index == draft.items.count - 1)
                            Button("移除此动作", role: .destructive) { draft.items.remove(at: index) }
                        } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                        .accessibilityLabel("动作 \(index + 1) 的操作").accessibilityIdentifier("template.itemMenu.\(index)")
                    }
                }
                .onMove { draft.items.move(fromOffsets: $0, toOffset: $1) }
                Button { focused = false; choosing = true } label: { Label("添加动作", systemImage: "plus") }.accessibilityIdentifier("template.addExercise")
            } header: { Text("计划动作") } footer: { Text("同一动作可多次添加；每个项目独立保存。点击项目配置目标，或使用右侧菜单调整顺序。") }
            Section("每周安排") {
                ForEach(1...7, id: \.self) { day in
                    Toggle(weekdayNames[day - 1], isOn: Binding(get: { draft.scheduledWeekdays.contains(day) }, set: { included in
                        draft.scheduledWeekdays.removeAll { $0 == day }; if included { draft.scheduledWeekdays.append(day) }; draft.scheduledWeekdays.sort()
                    })).accessibilityIdentifier("template.weekday.\(day)")
                }
            }
        }
        .navigationTitle("编辑训练模板").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            if focused { HStack { Spacer(); Button("完成") { focused = false }.frame(minWidth: 60, minHeight: 44).accessibilityIdentifier("template.keyboardDone") }.padding(.horizontal).background(.bar) }
        }
        .disabled(training.busy)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { if draft != original { discarding = true } else { dismiss() } }.accessibilityIdentifier("template.cancel") }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    focused = false
                    let value = draft
                    Task { if await training.run({ [repository = training.repository, catalog = training.catalog] in try await repository.saveTrainingTemplate(value, catalog: catalog) }) != nil { dismiss() } }
                }.disabled(training.busy || draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("template.save")
            }
        }
        .interactiveDismissDisabled(draft != original || training.busy)
        .sheet(isPresented: $choosing) {
            NavigationStack {
                ExerciseLibraryView { exercise in
                    draft.items.append(TrainingPlan.newItem(for: exercise, order: draft.items.count)); choosing = false
                }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { choosing = false } } }
            }
        }
        .sheet(item: $editingItem) { item in
            if let exercise = training.exercise(item.exerciseID) {
                NavigationStack { TemplateItemEditor(item: item, exercise: exercise) { edited in
                    if let index = draft.items.firstIndex(where: { $0.id == edited.id }) { draft.items[index] = edited }
                    editingItem = nil
                } }
            }
        }
        .confirmationDialog("放弃尚未保存的修改？", isPresented: $discarding, titleVisibility: .visible) {
            Button("放弃修改", role: .destructive) { dismiss() }
        }
    }
}

struct TemplateItemEditor: View {
    let exercise: Exercise
    let onSave: (TemplateItem) -> Void
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var item: TemplateItem
    @State private var input = TrainingTargetInput()
    @State private var error: String?
    @FocusState private var focused: Bool

    init(item: TemplateItem, exercise: Exercise, onSave: @escaping (TemplateItem) -> Void) {
        self.exercise = exercise; self.onSave = onSave; _item = State(initialValue: item)
    }
    var body: some View {
        Form {
            Section {
                Text(exercise.name).font(.headline)
                Stepper("计划组数：\(item.plannedSets)", value: $item.plannedSets, in: 1...1000).accessibilityIdentifier("targets.sets")
            }
            Section("每组目标（可选）") {
                switch exercise.measurement {
                case .externalLoad, .bodyweight, .assistedLoad:
                    field("最低次数", text: $input.minimum, id: "minimum", decimal: false)
                    field("最高次数", text: $input.maximum, id: "maximum", decimal: false)
                    if exercise.measurement != .bodyweight { field(preferences.values.weightUnit == .pounds ? "目标负重（lb）" : "目标负重（kg）", text: $input.load, id: "load") }
                case .duration: field("目标时长（秒）", text: $input.duration, id: "duration")
                case .cardio:
                    field("目标时长（秒）", text: $input.duration, id: "duration")
                    field(preferences.values.distanceUnit == .miles ? "目标距离（mi）" : "目标距离（km）", text: $input.distance, id: "distance")
                }
                field("组间休息（秒）", text: $input.rest, id: "rest")
            }
            if let error { Section { Text(error).accessibilityIdentifier("targets.error") } }
        }
        .navigationTitle("计划目标").navigationBarTitleDisplayMode(.inline)
        .task {
            func string(_ value: Double?) -> String { value.map { String(format: "%.6f", $0).replacingOccurrences(of: "0+$", with: "", options: .regularExpression).replacingOccurrences(of: "\\.$", with: "", options: .regularExpression) } ?? "" }
            input = TrainingTargetInput(minimum: item.minimumReps.map(String.init) ?? "", maximum: item.maximumReps.map(String.init) ?? "",
                                        load: string(item.loadKg.map { $0 / (preferences.values.weightUnit == .pounds ? 0.45359237 : 1) }),
                                        duration: string(item.durationSeconds), distance: string(item.distanceMeters.map { $0 / (preferences.values.distanceUnit == .miles ? 1609.344 : 1000) }), rest: string(item.restSeconds))
        }
        .safeAreaInset(edge: .bottom) {
            if focused { HStack { Spacer(); Button("完成") { focused = false }.frame(minWidth: 60, minHeight: 44).accessibilityIdentifier("targets.keyboardDone") }.padding(.horizontal).background(.bar) }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.accessibilityIdentifier("targets.cancel") }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存目标") {
                    do { onSave(try input.applying(to: item, measurement: exercise.measurement, pounds: preferences.values.weightUnit == .pounds, miles: preferences.values.distanceUnit == .miles)) }
                    catch { self.error = error.localizedDescription }
                }.accessibilityIdentifier("targets.save")
            }
        }
    }
    private func field(_ title: String, text: Binding<String>, id: String, decimal: Bool = true) -> some View {
        LabeledContent(title) { TextField("未设置", text: text).keyboardType(decimal ? .decimalPad : .numberPad).multilineTextAlignment(.trailing).focused($focused).accessibilityIdentifier("targets.\(id)") }
    }
}
