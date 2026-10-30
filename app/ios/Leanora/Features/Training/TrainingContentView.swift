import SwiftUI

struct TrainingProgramsView: View {
    @State private var programs: [TrainingContentCatalog.Program] = []
    @State private var error: String?
    var body: some View {
        List {
            Section {
                Text("从一套可修改的范例开始").font(.title2.bold()).accessibilityIdentifier("screen.programs")
                Text("先预览动作，再采用为自己的模板。重量留空，训练日由你安排。").foregroundStyle(.secondary)
            }
            if let error { Section { Label(error, systemImage: "exclamationmark.triangle") } }
            ForEach(programs) { program in
                NavigationLink { TrainingProgramDetailView(program: program) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(program.title).font(.headline)
                        Text(program.subtitle).font(.subheadline).foregroundStyle(.secondary)
                        Text("\(program.templates.count) 个模板 · \(program.equipment)").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 8)
                }.accessibilityIdentifier("program.\(program.id)")
            }
            Section("内容来源") {
                Text("Leanora 原创范例 · MIT。动作图示继续按详情中的各自许可和署名提供。").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("范例计划").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .task {
            do { programs = try TrainingContentCatalog.load().programs }
            catch { self.error = "随附范例暂时无法读取，仍可自行创建模板。" }
        }
    }
}

struct TrainingProgramDetailView: View {
    let program: TrainingContentCatalog.Program
    @Environment(TrainingStore.self) private var training
    @State private var adopted: [WorkoutTemplate] = []
    var body: some View {
        List {
            TrainingErrorNotice()
            Section {
                Text(program.title).font(.title2.bold())
                Text(program.summary)
                Label(program.equipment, systemImage: "dumbbell").font(.subheadline).foregroundStyle(.secondary)
                Text("仅浏览不会创建记录。采用后可自由编辑，不会覆盖已有模板和周安排。").font(.caption).foregroundStyle(.secondary)
            }
            if !adopted.isEmpty {
                Section("已加入我的模板") {
                    Label("\(adopted.count) 个模板已保存", systemImage: "checkmark.circle.fill").foregroundStyle(LeanoraTheme.accent).accessibilityIdentifier("program.adopted")
                    ForEach(adopted) { template in
                        NavigationLink(template.name) { TemplateDetailView(templateID: template.id) }.accessibilityIdentifier("program.saved.\(template.name)")
                    }
                }
            }
            ForEach(program.templates) { preset in
                Section(preset.title) {
                    ForEach(Array(preset.items.enumerated()), id: \.offset) { _, item in
                        if let exercise = training.exercise(item.exerciseID) {
                            NavigationLink { ExerciseDetailView(exerciseID: item.exerciseID) } label: {
                                HStack(spacing: 12) {
                                    if let image = ExerciseGuideCatalog.guide(for: item.exerciseID)?.images.first {
                                        ExerciseGuideImage(path: image).frame(width: 54, height: 58).clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityHidden(true)
                                    }
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(exercise.name).font(.headline)
                                        Text(targetText(item)).font(.caption).foregroundStyle(.secondary)
                                        if exercise.isArchived { Text("已归档，请先恢复或选用其他范例").font(.caption).foregroundStyle(.secondary) }
                                    }
                                }.padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            Section { Text("这是可编辑的记录范例，不会根据个人身体信息自动安排负重或训练频率。").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle(program.title).navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    if let saved = await training.run({ [repository = training.repository, catalog = training.catalog] in
                        try await repository.adoptTrainingProgram(program.id, catalog: catalog)
                    }) { adopted = saved }
                }
            } label: {
                Label(adopted.isEmpty ? "采用这 \(program.templates.count) 个模板" : "已添加到我的模板", systemImage: adopted.isEmpty ? "plus" : "checkmark")
            }.buttonStyle(PrimaryButtonStyle()).disabled(training.busy || !adopted.isEmpty)
                .accessibilityIdentifier("program.adopt.\(program.id)")
                .padding(.horizontal, 16).padding(.vertical, 10).background(.bar)
        }
    }
    private func targetText(_ item: TrainingContentCatalog.Item) -> String {
        let goal = item.seconds.map { "\($0.formatted()) 秒" } ?? "\(item.minimumReps ?? 0)–\(item.maximumReps ?? item.minimumReps ?? 0) 次"
        return "\(item.sets) 组 · \(goal) · 休息 \(item.restSeconds.formatted()) 秒"
    }
}

struct TrainingGuidesView: View {
    @State private var guides: [TrainingContentCatalog.Guide] = []
    @State private var error: String?
    var body: some View {
        List {
            Section { Text("把记录方式讲清楚").font(.title2.bold()).accessibilityIdentifier("screen.trainingGuides"); Text("8 篇离线指南，随时回看。Leanora 项目原创，按 MIT 提供。").foregroundStyle(.secondary) }
            if let error { Section { Label(error, systemImage: "exclamationmark.triangle") } }
            ForEach(guides) { guide in
                NavigationLink {
                    List {
                        Section { Text(guide.summary).font(.headline) }
                        ForEach(Array(guide.sections.enumerated()), id: \.offset) { _, section in
                            Section(section.title) {
                                ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in Text(paragraph).padding(.vertical, 4) }
                            }
                        }
                        Section { Text("Leanora 原创记录指南 · MIT").font(.footnote).foregroundStyle(.secondary) }
                    }.navigationTitle(guide.title).navigationBarTitleDisplayMode(.inline)
                        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
                        .accessibilityIdentifier("guide.article.\(guide.id)")
                } label: {
                    VStack(alignment: .leading, spacing: 6) { Text(guide.title).font(.headline); Text(guide.summary).font(.subheadline).foregroundStyle(.secondary) }.padding(.vertical, 5)
                }.accessibilityIdentifier("training.guide.\(guide.id)")
            }
        }.navigationTitle("记录指南").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .task {
            do { guides = try TrainingContentCatalog.load().guides }
            catch { self.error = "随附指南暂时无法读取，仍可继续手动记录。" }
        }
    }
}
