import SwiftUI

struct ExerciseLibraryView: View {
    @Environment(TrainingStore.self) private var training
    @State private var search = ""
    @State private var muscle = ""
    @State private var equipment = ""
    @State private var level = ""
    @State private var category = ""
    @State private var archived = false
    @State private var creating = false
    @State private var collection = "全部"
    var onSelect: ((Exercise) -> Void)?
    private var results: [Exercise] {
        let recent = training.recentExerciseIDs
        let values = training.exercises.filter { collection == "收藏" ? $0.isFavorite == true : collection == "最近" ? recent.contains($0.id) : true }
        let found = ExerciseSearch.filter(values, query: search, muscle: muscle.isEmpty ? nil : muscle, equipment: equipment.isEmpty ? nil : equipment, archived: archived, level: level.isEmpty ? nil : level, category: category.isEmpty ? nil : category)
        return collection == "最近" ? found.sorted { (recent.firstIndex(of: $0.id) ?? .max) < (recent.firstIndex(of: $1.id) ?? .max) } : found
    }
    var body: some View {
        List {
            TrainingErrorNotice()
            Section {
                Picker("动作分组", selection: $collection) {
                    ForEach(["全部", "收藏", "最近"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("exercise.collection")
            }
            Section("筛选") {
                Picker("肌群", selection: $muscle) {
                    Text("全部肌群").tag("")
                    ForEach(Array(Set(training.exercises.flatMap(\.muscles))).sorted(), id: \.self) { Text($0).tag($0) }
                }.accessibilityIdentifier("exercise.muscle")
                Picker("器械", selection: $equipment) {
                    Text("全部器械").tag("")
                    ForEach(Array(Set(training.exercises.map(\.equipment))).filter { !$0.isEmpty }.sorted(), id: \.self) { Text($0).tag($0) }
                }.accessibilityIdentifier("exercise.equipment")
                DisclosureGroup("更多筛选") {
                    Picker("难度", selection: $level) {
                        Text("全部难度").tag("")
                        ForEach(["初级", "中级", "高级", "未分级"], id: \.self) { Text($0).tag($0) }
                    }.accessibilityIdentifier("exercise.level")
                    Picker("类型", selection: $category) {
                        Text("全部类型").tag("")
                        ForEach(["力量", "有氧", "拉伸", "爆发力", "力量举", "举重", "大力士"], id: \.self) { Text($0).tag($0) }
                    }.accessibilityIdentifier("exercise.category")
                }.accessibilityIdentifier("exercise.moreFilters")
                if !muscle.isEmpty || !equipment.isEmpty || !level.isEmpty || !category.isEmpty {
                    Button("清除筛选") { muscle = ""; equipment = ""; level = ""; category = "" }.accessibilityIdentifier("exercise.clearFilters")
                }
                if onSelect == nil { Toggle("查看已归档动作", isOn: $archived).accessibilityIdentifier("exercise.archived") }
            }
            Section {
                Button { creating = true } label: { Label("新建自定义动作", systemImage: "plus") }.accessibilityIdentifier("exercise.new")
                if results.isEmpty {
                    ContentUnavailableView(collection == "收藏" ? "还没有匹配的收藏" : collection == "最近" ? "还没有匹配的最近动作" : "没有匹配动作",
                        systemImage: collection == "收藏" ? "star" : "magnifyingglass",
                        description: Text(collection == "收藏" ? "在动作详情或左滑列表即可收藏；也可以调整筛选。" : collection == "最近" ? "完成训练后，这里会显示最近 20 个实际练过的动作。" : "调整筛选条件，或创建自己的动作。"))
                    if collection != "全部" { Button("查看全部动作") { collection = "全部" }.accessibilityIdentifier("exercise.showAll") }
                }
                ForEach(results) { exercise in
                    if let onSelect {
                        HStack(spacing: 12) {
                            Button { onSelect(exercise) } label: { row(exercise) }.buttonStyle(.borderless)
                                .accessibilityIdentifier("exercise.select.\(exercise.name)")
                            if ExerciseGuideCatalog.guide(for: exercise.id) != nil {
                                NavigationLink { ExerciseGuidanceView(exerciseID: exercise.id, name: exercise.name) } label: {
                                    Image(systemName: "info.circle").frame(minWidth: 44, minHeight: 44)
                                }.accessibilityLabel("\(exercise.name)，查看指导").accessibilityIdentifier("exercise.info.\(exercise.name)")
                            }
                        }
                    } else {
                        NavigationLink { ExerciseDetailView(exerciseID: exercise.id) } label: { row(exercise) }.accessibilityIdentifier("exercise.row.\(exercise.name)")
                            .swipeActions(edge: .trailing) {
                                Button(exercise.isFavorite == true ? "取消收藏" : "收藏", systemImage: "star") { Task { await training.setFavorite(exercise) } }.tint(LeanoraTheme.accent)
                            }
                    }
                }
            } header: { Text("\(results.count) 个动作").accessibilityIdentifier("exercise.resultCount") } footer: { Text("内置指导图可离线查看。部分名称与步骤保留英文原文；来源与许可见详情。") }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索名称或别名")
        .navigationTitle(onSelect == nil ? "动作库" : "选择动作").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .sheet(isPresented: $creating) { NavigationStack { CustomExerciseEditor(exercise: Exercise(name: "")) } }
    }
    private func row(_ exercise: Exercise) -> some View {
        HStack(spacing: 12) {
            if let guide = ExerciseGuideCatalog.guide(for: exercise.id), let first = guide.images.first {
                ExerciseGuideImage(path: first).frame(width: 60, height: 64).clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name).font(.headline).foregroundStyle(.primary)
                if exercise.isFavorite == true { Label("已收藏", systemImage: "star.fill").font(.caption).foregroundStyle(LeanoraTheme.accent) }
                Text("\(exercise.equipment) · \(exercise.measurement.title)").font(.subheadline).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
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
                    Button {
                        Task { await training.setFavorite(exercise) }
                    } label: {
                        Label(exercise.isFavorite == true ? "取消收藏" : "收藏动作", systemImage: exercise.isFavorite == true ? "star.fill" : "star")
                    }.disabled(training.busy).accessibilityIdentifier("exercise.favorite")
                }
                if let guide = ExerciseGuideCatalog.guide(for: exercise.id) {
                    ExerciseGuideSections(guide: guide, name: exercise.name)
                }
                Section("记录资料") {
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
