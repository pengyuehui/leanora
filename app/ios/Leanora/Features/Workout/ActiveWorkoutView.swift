import SwiftUI

struct ActiveWorkoutView: View {
    let sessionID: UUID
    @Environment(TrainingStore.self) private var training
    @Environment(NotificationPermissionService.self) private var notifications
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var editing: SetSelection?
    @State private var finishing = false
    @State private var abandoning = false
    @State private var deleting = false
    @State private var removed: SetSelection?
    @State private var editingNotes = false
    @State private var notes = ""
    @State private var retiming = false
    @State private var guidance: GuideSelection?
    @State private var choosing = false
    @State private var renaming = false
    @State private var removingExerciseID: UUID?
    @State private var templateDraft: WorkoutTemplate?
    @State private var updatingTemplate = false
    var session: WorkoutSession? { training.sessions.first { $0.id == sessionID } }
    var body: some View {
        List {
            TrainingErrorNotice()
            if let session {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.name).font(.title2.weight(.semibold)).accessibilityIdentifier("workout.started")
                        Text(session.status == .completed ? "训练已完成" : session.status == .paused ? "训练已暂停" : "训练进行中")
                            .accessibilityIdentifier("workout.status")
                        Text("归属日期：\(session.started.localDate) · 本机记录").font(.caption).foregroundStyle(.secondary)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text("有效时长 \(Int(TrainingSummary.activeDuration(session, at: context.date))) 秒").monospacedDigit()
                            if let deadline = session.restDeadline {
                                Text(deadline > context.date ? "休息剩余 \(Int(ceil(deadline.timeIntervalSince(context.date)))) 秒" : "休息已结束，可以继续下一组")
                                    .foregroundStyle(LeanoraTheme.accent).accessibilityIdentifier("workout.rest")
                            }
                        }
                    }.padding(.vertical, 4)
                    if [.active, .paused].contains(session.status) {
                        Button("修改训练名称") { renaming = true }.accessibilityIdentifier("workout.rename")
                    }
                    if session.status == .completed { Button("更正开始时间") { retiming = true }.accessibilityIdentifier("workout.retime") }
                    if session.status != .completed {
                        HStack {
                            Button(session.status == .paused ? "继续训练" : "暂停训练") {
                                Task { _ = await controller.change(session) { value in
                                    if value.status == .paused { try WorkoutEngine.resume(&value, at: Date()) }
                                    else { try WorkoutEngine.pause(&value, at: Date()) }
                                } }
                            }.accessibilityIdentifier("workout.pause")
                            if session.restDeadline != nil {
                                Button("结束休息") { Task { _ = await controller.change(session) { $0.restDeadline = nil } } }.accessibilityIdentifier("workout.skipRest")
                                Button("延长 30 秒") { Task { _ = await controller.change(session) { $0.restDeadline = max($0.restDeadline ?? Date(), Date()).addingTimeInterval(30) } } }
                            }
                        }.buttonStyle(.borderless)
                        if notifications.access != .allowed {
                            Button("开启系统休息提醒") { Task { await notifications.request(); await training.refresh() } }.accessibilityIdentifier("workout.notifications")
                        }
                    }
                }
                if [.active, .paused].contains(session.status) {
                    Section {
                        if session.exercises.isEmpty {
                            Text("还没有动作。添加想练的动作，再逐组记录实际表现。").foregroundStyle(.secondary).accessibilityIdentifier("workout.empty")
                        }
                        Button { choosing = true } label: { Label("添加动作", systemImage: "plus") }.accessibilityIdentifier("workout.addExercise")
                    }
                }
                ForEach(Array(session.exercises.enumerated()), id: \.element.id) { i, exercise in
                    Section {
                        let reference = WorkoutReuse.reference(for: exercise, in: session, history: training.sessions)
                        if ExerciseGuideCatalog.guide(for: exercise.snapshot.exerciseID) != nil {
                            Button { guidance = GuideSelection(id: exercise.snapshot.exerciseID, name: exercise.snapshot.name) } label: {
                                Label("查看动作指导", systemImage: "photo.on.rectangle")
                            }.accessibilityIdentifier("workout.guide.\(i)")
                        }
                        if let plan = exercise.plannedTargets {
                            Text(planText(plan)).font(.caption).foregroundStyle(.secondary)
                        }
                        if let reference {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("上次训练 · \(reference.date)", systemImage: "clock.arrow.circlepath").font(.subheadline.weight(.medium))
                                    .accessibilityIdentifier("workout.previous.\(i)")
                                DisclosureGroup("上次完成 \(reference.exercise.sets.filter { $0.completedAt != nil }.count) 组") {
                                    ForEach(reference.exercise.sets.filter { $0.completedAt != nil }, id: \.id) { old in
                                        Text("\(old.kind.title) · \(actualText(old, measurement: exercise.snapshot.measurement, prefix: "上次"))").font(.caption)
                                    }
                                }
                                if [.active, .paused].contains(session.status) {
                                    Button("沿用上次") {
                                        Task { _ = await controller.change(session) { $0.exercises[i] = WorkoutReuse.applying(reference, to: $0.exercises[i]) } }
                                    }.buttonStyle(.borderless).frame(minHeight: 44).accessibilityIdentifier("workout.reusePrevious.\(i)")
                                    Text("只填入尚未完成、也未计时的组，已记录的完成值保持。").font(.caption).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 4)
                        }
                        if exercise.supersetID != nil { Label("超级组 · 同轮两个动作完成后休息", systemImage: "link").font(.caption) }
                        ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { j, set in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Button { editing = SetSelection(exercise: i, set: j) } label: {
                                        HStack(spacing: 12) {
                                            VStack(spacing: 3) { Text("\(j + 1)").font(.headline.monospacedDigit()); Text(set.kind.title).font(.caption2).foregroundStyle(.secondary) }.frame(minWidth: 30)
                                            Text(actualText(set, measurement: exercise.snapshot.measurement)).font(.body.monospacedDigit()).frame(maxWidth: .infinity, alignment: .leading)
                                            Image(systemName: "pencil").font(.caption).foregroundStyle(.secondary)
                                        }.frame(minHeight: 48).contentShape(Rectangle())
                                    }.buttonStyle(.plain).accessibilityLabel("第 \(j + 1) 组，\(set.kind.title)，\(actualText(set, measurement: exercise.snapshot.measurement))，\(set.completedAt == nil ? "未完成，编辑" : "已完成，编辑")").accessibilityIdentifier("workout.set.\(i).\(j)")
                                    if session.status == .active && set.completedAt == nil {
                                        Button { Task { _ = await controller.change(session) { try WorkoutEngine.complete(&$0, exercise: i, set: j, at: Date()) } } } label: { Image(systemName: "checkmark.circle").font(.title).frame(width: 44, height: 48) }
                                            .accessibilityLabel("完成此组").buttonStyle(.borderless).accessibilityIdentifier("workout.complete.\(i).\(j)")
                                    } else if set.completedAt != nil { Image(systemName: "checkmark.circle.fill").font(.title).foregroundStyle(LeanoraTheme.accent).frame(width: 44).accessibilityLabel("已完成") }
                                }
                                if let reference, let previous = WorkoutReuse.previousSet(for: set, in: exercise, reference: reference) {
                                    Text(actualText(previous, measurement: exercise.snapshot.measurement, prefix: "上次")).font(.caption).foregroundStyle(.secondary)
                                        .accessibilityIdentifier("workout.previousSet.\(i).\(j)")
                                }
                                if [.duration, .cardio].contains(exercise.snapshot.measurement), set.completedAt == nil, session.status != .completed {
                                    HStack {
                                        TimelineView(.periodic(from: .now, by: 1)) { context in Text("动作计时 \(Int(WorkoutEngine.elapsed(set, at: context.date))) 秒").monospacedDigit() }
                                        Button(set.timerStartedAt == nil ? "开始计时" : "停止计时") {
                                            Task { _ = await controller.change(session) { try WorkoutEngine.toggleTimer(&$0, exercise: i, set: j, at: Date()) } }
                                        }.disabled(session.status != .active).accessibilityIdentifier("workout.timer.\(i).\(j)")
                                    }.buttonStyle(.borderless)
                                }
                            }.padding(.vertical, 6)
                            .listRowBackground(set.completedAt == nil ? LeanoraTheme.surface : LeanoraTheme.accent.opacity(0.08))
                            .swipeActions { Button("删除组", role: .destructive) { removed = SetSelection(exercise: i, set: j) } }
                        }
                        Button("添加一组") {
                            Task { _ = await controller.change(session) { $0.exercises[i].sets.append(WorkoutSet(order: $0.exercises[i].sets.count)) } }
                        }.accessibilityIdentifier("workout.addSet.\(i)")
                    } header: {
                        HStack {
                            Text("\(i + 1). \(exercise.snapshot.name)")
                            Spacer()
                            if [.active, .paused].contains(session.status) {
                                Menu {
                                    Button("上移动作") { moveExercise(session, index: i, step: -1) }.disabled(i == 0)
                                    Button("下移动作") { moveExercise(session, index: i, step: 1) }.disabled(i == session.exercises.count - 1)
                                    Button("移除动作", role: .destructive) { removingExerciseID = exercise.id }
                                } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }
                                .accessibilityLabel("动作 \(i + 1) 的操作").accessibilityIdentifier("workout.exerciseMenu.\(i)")
                            }
                        }
                    }
                }
                Section("训练备注") {
                    if !session.notes.isEmpty { Text(session.notes) }
                    Button("编辑备注") { notes = session.notes; editingNotes = true }.accessibilityIdentifier("workout.notes")
                }
                Section {
                    if session.status == .completed {
                        let summary = TrainingSummary(sessions: [session])
                        Text("工作组容量：\(summary.volumeKg.formatted()) kg·次")
                        Text("仅统计已完成的外部负重正式组；不含热身、自重、辅助负重与计时。 ").font(.caption).foregroundStyle(.secondary)
                        Button("存为新模板") { prepareTemplate(session, updateOriginal: false) }.accessibilityIdentifier("workout.saveTemplate")
                        if session.templateID != nil {
                            Button("更新原模板") { updatingTemplate = true }.disabled(!canUpdateTemplate(session)).accessibilityIdentifier("workout.updateTemplate")
                            if !canUpdateTemplate(session) { Text("原模板已更新或移除，请存为新模板。").font(.caption).foregroundStyle(.secondary) }
                        }
                        Text("模板草稿仅提取已完成正式组，组数按实际、目标取首组；其他组类型仍保留在训练历史。保存前可以继续编辑。").font(.caption).foregroundStyle(.secondary)
                        Button("删除训练记录", role: .destructive) { deleting = true }.accessibilityIdentifier("workout.delete")
                    } else {
                        Button("放弃本次训练", role: .destructive) { abandoning = true }.accessibilityIdentifier("workout.abandon")
                    }
                }
            }
        }
        .navigationTitle("本次训练").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .safeAreaInset(edge: .bottom) {
            if let session, session.status != .completed {
                VStack(spacing: 8) {
                    if let deadline = session.restDeadline {
                        HStack {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Label(deadline > context.date ? "休息 \(Int(ceil(deadline.timeIntervalSince(context.date)))) 秒" : "休息结束", systemImage: "timer").font(.headline.monospacedDigit())
                            }
                            Spacer()
                            Button("跳过") { Task { _ = await controller.change(session) { $0.restDeadline = nil } } }.frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("workout.restSkip")
                        }
                    }
                    Button("完成训练") { finishing = true }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("workout.finish")
                }.padding(.horizontal, 16).padding(.vertical, 10).background(.bar)
            }
        }
        .disabled(training.busy)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.accessibilityIdentifier("workout.close") } }
        .task { await notifications.refresh() }
        .sheet(item: $editing) { selection in
            if let session { NavigationStack { WorkoutSetEditor(session: session, selection: selection) } }
        }
        .sheet(isPresented: $retiming) { if let session { NavigationStack { WorkoutTimeEditor(session: session) } } }
        .sheet(item: $templateDraft) { draft in NavigationStack { TemplateEditorView(template: draft) } }
        .sheet(isPresented: $choosing) {
            NavigationStack {
                ExerciseLibraryView { exercise in
                    if let session {
                        Task {
                            if await training.run({ [repository = training.repository, catalog = training.catalog] in
                                try await repository.addExerciseToWorkout(session.id, revision: session.stamp.revision, exerciseID: exercise.id, catalog: catalog)
                            }) != nil { choosing = false }
                        }
                    }
                }.disabled(training.busy)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { choosing = false } } }
            }
        }
        .sheet(isPresented: $renaming) {
            if let session { NavigationStack { WorkoutNameEditor(session: session) } }
        }
        .sheet(item: $guidance) { selected in
            NavigationStack {
                ExerciseGuidanceView(exerciseID: selected.id, name: selected.name)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("关闭指导") { guidance = nil }.accessibilityIdentifier("workout.closeGuide") } }
            }
        }
        .sheet(isPresented: $editingNotes) {
            NavigationStack {
                Form { TextField("训练备注", text: $notes, axis: .vertical).accessibilityIdentifier("workout.notesInput") }
                    .navigationTitle("训练备注")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("取消") { editingNotes = false } }
                        ToolbarItem(placement: .confirmationAction) { Button("保存") { if let session { Task { if await controller.change(session, { $0.notes = notes }) { editingNotes = false } } } } }
                    }
            }
        }
        .confirmationDialog("结束并保存训练？未完成组不计入统计。", isPresented: $finishing, titleVisibility: .visible) {
            Button("确认完成") { Task {
                if await training.run({ [repository = training.repository] in try await repository.finishWorkout(sessionID) }) != nil { dismiss() }
            } }.accessibilityIdentifier("workout.confirmFinish")
        }
        .confirmationDialog("放弃本次训练？", isPresented: $abandoning, titleVisibility: .visible) {
            Button("确认放弃", role: .destructive) { Task { if await training.run({ [repository = training.repository] in try await repository.abandonTraining(sessionID) }) != nil { dismiss() } } }
        } message: { Text("保留这次放弃记录，之后可以重新开始训练。") }
        .confirmationDialog("移除此动作及本次的组记录？", isPresented: Binding(get: { removingExerciseID != nil }, set: { if !$0 { removingExerciseID = nil } }), titleVisibility: .visible) {
            Button("确认移除动作", role: .destructive) {
                if let session, let id = removingExerciseID {
                    Task { _ = await controller.change(session) { try WorkoutReuse.removeExercise(id, from: &$0) }; removingExerciseID = nil }
                }
            }.accessibilityIdentifier("workout.confirmRemoveExercise")
        } message: { Text("只改变本次训练；如属于超级组，另一个动作会解除配对。原模板与其他历史不变。") }
        .confirmationDialog("按本次正式组准备原模板更新？", isPresented: $updatingTemplate, titleVisibility: .visible) {
            Button("生成更新草稿") { if let session { prepareTemplate(session, updateOriginal: true) } }.accessibilityIdentifier("workout.confirmUpdateTemplate")
        } message: { Text("保留原模板名称和周安排，先打开草稿供你检查，点击保存后才更新。已完成训练不会被修改。") }
        .confirmationDialog("删除训练及其组记录？", isPresented: $deleting, titleVisibility: .visible) {
            Button("确认删除", role: .destructive) { removeWorkout(health: false) }
            Button("同时删除健康副本", role: .destructive) { removeWorkout(health: true) }
        } message: { Text("「确认删除」仅移除本机记录。你也可以同步移除本 App 写入的健康副本。") }
        .confirmationDialog("删除这一组？统计与最佳负重会重新计算。", isPresented: Binding(get: { removed != nil }, set: { if !$0 { removed = nil } }), titleVisibility: .visible) {
            Button("删除组", role: .destructive) { if let session, let removed { Task {
                _ = await controller.change(session) { value in
                    value.exercises[removed.exercise].sets.remove(at: removed.set)
                    for j in value.exercises[removed.exercise].sets.indices { value.exercises[removed.exercise].sets[j].order = j }
                }; self.removed = nil
            } } }
        }
    }
    private var controller: WorkoutSessionController { WorkoutSessionController(training: training) }
    private struct GuideSelection: Identifiable { let id: UUID; let name: String }
    private func canUpdateTemplate(_ session: WorkoutSession) -> Bool {
        training.templates.contains { $0.id == session.templateID && $0.stamp.revision == session.templateRevision }
    }
    private func prepareTemplate(_ session: WorkoutSession, updateOriginal: Bool) {
        Task {
            templateDraft = await training.run { [repository = training.repository, catalog = training.catalog] in
                try await repository.templateFromWorkout(session.id, updateOriginal: updateOriginal, catalog: catalog)
            }
        }
    }
    private func moveExercise(_ session: WorkoutSession, index: Int, step: Int) {
        Task {
            _ = await controller.change(session) { value in
                guard value.exercises.indices.contains(index), value.exercises.indices.contains(index + step) else { throw TrainingProblem.missingRecord }
                value.exercises.swapAt(index, index + step)
                for i in value.exercises.indices { value.exercises[i].order = i }
            }
        }
    }
    private func removeWorkout(health: Bool) {
        guard let session else { return }
        Task { if await training.run({ [repository = training.repository] in try await repository.deleteWorkout(sessionID, revision: session.stamp.revision, deleteHealthCopies: health) }) != nil { dismiss() } }
    }
    private func planText(_ p: PlannedTargets) -> String {
        var parts = ["计划 \(p.sets) 组"]
        if let n = p.minimumReps { parts.append("\(n)–\(p.maximumReps ?? n) 次") }
        if let kg = p.loadKg { parts.append("\((kg / (preferences.values.weightUnit == .pounds ? 0.45359237 : 1)).formatted()) \(preferences.values.weightUnit.rawValue)") }
        if let sec = p.durationSeconds { parts.append("\(sec.formatted()) 秒") }
        parts.append("休息 \(p.restSeconds.formatted()) 秒"); return parts.joined(separator: " · ")
    }
    private func actualText(_ set: WorkoutSet, measurement: ExerciseMeasurement, prefix: String = "实际") -> String {
        switch measurement {
        case .externalLoad, .assistedLoad:
            let weight = set.loadKg.map { ($0 / (preferences.values.weightUnit == .pounds ? 0.45359237 : 1)).formatted() } ?? "—"
            return "\(prefix) \(weight) \(preferences.values.weightUnit.rawValue) × \(set.repetitions.map(String.init) ?? "—") 次"
        case .bodyweight: return "\(prefix) \(set.repetitions.map(String.init) ?? "—") 次"
        case .duration, .cardio: return "\(prefix) \(set.durationSeconds.map { $0.formatted() } ?? "—") 秒 · \(set.distanceMeters.map { $0.formatted() } ?? "—") m"
        }
    }
}

struct WorkoutNameEditor: View {
    let session: WorkoutSession
    @Environment(TrainingStore.self) private var training
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    init(session: WorkoutSession) { self.session = session; _name = State(initialValue: session.name) }
    var body: some View {
        Form {
            TrainingErrorNotice()
            HStack {
                TextField("训练名称", text: $name).accessibilityIdentifier("workout.nameInput")
                if !name.isEmpty {
                    Button { name = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).frame(width: 44, height: 44) }
                        .buttonStyle(.borderless).accessibilityLabel("清空训练名称").accessibilityIdentifier("workout.clearName")
                }
            }
        }.navigationTitle("训练名称").navigationBarTitleDisplayMode(.inline)
        .disabled(training.busy)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    let updated = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task { if await WorkoutSessionController(training: training).change(session, { $0.name = updated }) { dismiss() } }
                }.disabled(training.busy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("workout.saveName")
            }
        }
    }
}

struct WorkoutTimeEditor: View {
    let session: WorkoutSession
    @Environment(TrainingStore.self) private var training
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var confirming = false
    var body: some View {
        Form {
            RecordDatePicker(title: "实际开始时间", selection: $date)
            Text("归属日期将变为 \(RecordMoment(date).localDate)。结束、暂停及完成组的时刻会同步平移，实际训练时长保持不变。")
            TrainingErrorNotice()
        }.navigationTitle("更正训练时间")
            .task { date = session.started.instant }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { confirming = true }.disabled(training.busy) }
            }
            .confirmationDialog("确认调整时间并重新归日？", isPresented: $confirming, titleVisibility: .visible) {
                Button("确认更改日期") {
                    let started = date
                    Task { if await training.run({ [repository = training.repository] in try await repository.retimeWorkout(session.id, revision: session.stamp.revision, started: started, timeZoneID: TimeZone.current.identifier) }) != nil { dismiss() } }
                }
            }
    }
}

struct SetSelection: Identifiable { var exercise: Int; var set: Int; var id: String { "\(exercise).\(set)" } }
extension WorkoutSetKind: CaseIterable {
    static var allCases: [Self] { [.working, .warmup, .drop, .failure] }
    var title: String { switch self { case .working: "正式组"; case .warmup: "热身组"; case .drop: "递减组"; case .failure: "力竭组" } }
}

struct WorkoutSetEditor: View {
    let session: WorkoutSession
    let selection: SetSelection
    @Environment(TrainingStore.self) private var training
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var load = ""
    @State private var reps = ""
    @State private var duration = ""
    @State private var distance = ""
    @State private var effort = ""
    @State private var scale = EffortScale.rpe
    @State private var kind = WorkoutSetKind.working
    @State private var completed = false
    @State private var error: String?
    @FocusState private var focused: Bool
    private var exercise: SessionExercise { session.exercises[selection.exercise] }
    private var set: WorkoutSet { exercise.sets[selection.set] }
    var body: some View {
        Form {
            TrainingErrorNotice()
            Section("实际完成值") {
                Text(exercise.snapshot.name)
                Picker("组类型", selection: $kind) { ForEach(WorkoutSetKind.allCases, id: \.self) { Text($0.title).tag($0) } }.accessibilityIdentifier("set.kind")
                if [.externalLoad, .assistedLoad].contains(exercise.snapshot.measurement) { input("负重（\(preferences.values.weightUnit.rawValue)）", $load, "load") }
                if [.externalLoad, .bodyweight, .assistedLoad].contains(exercise.snapshot.measurement) { input("次数", $reps, "reps") }
                if [.duration, .cardio].contains(exercise.snapshot.measurement) { input("时长（秒）", $duration, "duration") }
                if exercise.snapshot.measurement == .cardio { input("距离（\(preferences.values.distanceUnit.rawValue)）", $distance, "distance") }
                Picker("主观强度", selection: $scale) { Text("RPE").tag(EffortScale.rpe); Text("RIR").tag(EffortScale.rir) }
                input(scale == .rpe ? "RPE（0–10，可留空）" : "RIR（0–10，可留空）", $effort, "effort")
                if set.completedAt != nil { Toggle("该组已完成", isOn: $completed).accessibilityIdentifier("set.completed") }
                Text("保存实际值不会自动完成这一组。最近值预填也需要确认完成。").font(.caption).foregroundStyle(.secondary)
            }
            if let error { Text(error).accessibilityIdentifier("set.error") }
        }
        .navigationTitle("编辑第 \(selection.set + 1) 组").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { if focused { HStack { Spacer(); Button("完成输入") { focused = false }.frame(minHeight: 44).accessibilityIdentifier("set.keyboardDone") }.padding(.horizontal).background(.bar) } }
        .task {
            load = number(set.loadKg.map { $0 / (preferences.values.weightUnit == .pounds ? 0.45359237 : 1) }); reps = set.repetitions.map(String.init) ?? ""
            duration = number(set.durationSeconds); distance = number(set.distanceMeters.map { $0 / (preferences.values.distanceUnit == .miles ? 1609.344 : 1000) })
            effort = number(set.effort?.value); scale = set.effort?.scale ?? .rpe; kind = set.kind; completed = set.completedAt != nil
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(training.busy).accessibilityIdentifier("set.save") }
        }
    }
    private func number(_ value: Double?) -> String { value.map { $0.formatted(.number.grouping(.never).precision(.fractionLength(0...4))) } ?? "" }
    private func input(_ label: String, _ value: Binding<String>, _ id: String) -> some View {
        LabeledContent(label) {
            HStack { TextField("未填写", text: value).keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($focused).accessibilityIdentifier("set.\(id)")
                Button { value.wrappedValue = "" } label: { Image(systemName: "xmark.circle").frame(minWidth: 44, minHeight: 44) }.buttonStyle(.borderless).accessibilityLabel("清空\(label)").accessibilityIdentifier("set.clear.\(id)") }
        }
    }
    private func save() {
        do {
            var value = set; value.kind = kind
            value.loadKg = try TrainingTargetInput.decimal(load).map { $0 * (preferences.values.weightUnit == .pounds ? 0.45359237 : 1) }
            value.repetitions = try TrainingTargetInput.integer(reps); value.durationSeconds = try TrainingTargetInput.decimal(duration)
            value.distanceMeters = try TrainingTargetInput.decimal(distance).map { $0 * (preferences.values.distanceUnit == .miles ? 1609.344 : 1000) }
            value.effort = try TrainingTargetInput.decimal(effort).map { EffortValue(scale: scale, value: $0) }
            if !completed { value.completedAt = nil }
            if value.timerStartedAt == nil { value.accumulatedSeconds = value.durationSeconds ?? 0 }
            let edited = value
            Task { if await WorkoutSessionController(training: training).change(session, { $0.exercises[selection.exercise].sets[selection.set] = edited }) { dismiss() } }
        } catch { self.error = error.localizedDescription }
    }
}
