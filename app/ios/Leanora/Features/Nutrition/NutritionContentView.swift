import SwiftUI

struct NutritionExamplesView: View {
    @State private var examples: [NutritionContentCatalog.Recipe] = []
    @State private var error: String?
    var body: some View {
        List {
            Section {
                Text("先看食材，再变成自己的组合").font(.title2.bold()).accessibilityIdentifier("screen.nutritionExamples")
                Text("6 套原创搭配，用来演示记录方法。食材和份量都可以修改，不是个人饮食处方。").foregroundStyle(.secondary)
            }
            if let error { Label(error, systemImage: "exclamationmark.triangle") }
            ForEach(examples) { recipe in
                NavigationLink { NutritionExampleDetailView(recipe: recipe) } label: {
                    VStack(alignment: .leading, spacing: 6) { Text(recipe.title).font(.headline); Text(recipe.subtitle).font(.subheadline).foregroundStyle(.secondary) }.padding(.vertical, 6)
                }.accessibilityIdentifier("nutrition.example.\(recipe.id)")
            }
            Section("内容来源") { Text("Leanora 原创搭配与说明 · MIT。食品数据来自 USDA FoodData Central · CC0。营养按所列食材状态和份量计算，额外配料需另记。").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle("食物搭配范例").navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
            .task { do { examples = try NutritionContentCatalog.load().recipes } catch { self.error = "随附搭配暂时无法读取，仍可自行创建组合。" } }
    }
}

private struct NutritionExampleDetailView: View {
    let recipe: NutritionContentCatalog.Recipe
    @Environment(JournalStore.self) private var journal
    @State private var preview: MealTemplate?
    @State private var editing: MealTemplate?
    @State private var error: String?
    var body: some View {
        List {
            Section { Text(recipe.title).font(.title2.bold()); Text(recipe.subtitle).foregroundStyle(.secondary) }
            if let preview {
                Section("按下面全部食材计算") { NutritionSummaryView(summary: NutritionSummary(entries: (try? preview.entries(servings: 1, meal: .lunch, date: Date())) ?? [])) }
                Section("食材与份量") { ForEach(preview.items) { item in
                    VStack(alignment: .leading, spacing: 5) { MealItemLabel(item: item); Text(item.food?.source.name ?? "").font(.caption).foregroundStyle(.secondary) }
                } }
            }
            Section("计算口径") { Text(recipe.notes).font(.footnote).foregroundStyle(.secondary) }
            Section { Text("仅预览不会写入日记或创建组合。采用后先打开草稿，检查并明确保存。").font(.caption) }
            if let error { Label(error, systemImage: "exclamationmark.triangle") }
        }.navigationTitle("搭配详情").navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
            .safeAreaInset(edge: .bottom) {
                Button("采用为组合草稿", systemImage: "square.and.pencil") {
                    if let preview { var copy = preview.copied(); copy.name = recipe.title; editing = copy }
                }.buttonStyle(PrimaryButtonStyle()).disabled(preview == nil).accessibilityIdentifier("nutrition.example.adopt")
                    .padding(.horizontal, 16).padding(.vertical, 10).background(.bar)
            }
            .task { do { preview = try NutritionContentCatalog.load().draft(recipeID: recipe.id, foods: journal.catalog) } catch { self.error = "这个搭配暂时无法读取，请返回查看其他内容。" } }
            .sheet(item: $editing) { draft in NavigationStack { MealTemplateEditorView(draft: draft) } }
    }
}

struct NutritionGuidesView: View {
    @State private var guides: [NutritionContentCatalog.Guide] = []
    @State private var error: String?
    var body: some View {
        List {
            Section { Text("把每一餐记清楚").font(.title2.bold()).accessibilityIdentifier("screen.nutritionGuides"); Text("8 篇原创离线指南，解释记录口径、未知值和复用方法。").foregroundStyle(.secondary) }
            if let error { Label(error, systemImage: "exclamationmark.triangle") }
            ForEach(guides) { guide in
                NavigationLink {
                    List {
                        Section { Text(guide.summary).font(.headline) }
                        ForEach(Array(guide.sections.enumerated()), id: \.offset) { _, section in
                            Section(section.title) { ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in Text(paragraph).padding(.vertical, 4) } }
                        }
                        Section { Text("Leanora 原创记录指南 · MIT").font(.footnote).foregroundStyle(.secondary) }
                    }.navigationTitle(guide.title).navigationBarTitleDisplayMode(.inline)
                        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas).accessibilityIdentifier("nutrition.article.\(guide.id)")
                } label: { VStack(alignment: .leading, spacing: 6) { Text(guide.title).font(.headline); Text(guide.summary).font(.subheadline).foregroundStyle(.secondary) }.padding(.vertical, 5) }
                    .accessibilityIdentifier("nutrition.guide.\(guide.id)")
            }
        }.navigationTitle("饮食记录指南").navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
            .task { do { guides = try NutritionContentCatalog.load().guides } catch { self.error = "随附指南暂时无法读取，仍可继续手动记录。" } }
    }
}
