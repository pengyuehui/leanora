import SwiftUI

enum JournalKind: String {
    case training, nutrition, trends
    var title: String {
        switch self { case .training: "训练"; case .nutrition: "饮食"; case .trends: "趋势" }
    }
    var headline: String {
        switch self {
        case .training: "每一组，\n都值得记住。"
        case .nutrition: "一日三餐，\n照顾好自己。"
        case .trends: "变化很慢，\n记录看得见。"
        }
    }
    var symbol: String {
        switch self { case .training: "dumbbell"; case .nutrition: "fork.knife"; case .trends: "chart.xyaxis.line" }
    }
    var empty: String {
        switch self { case .training: "还没有训练记录"; case .nutrition: "还没有饮食记录"; case .trends: "还没有可展示的趋势" }
    }
    var detail: String {
        switch self {
        case .training: "训练日记会留住动作、重量与次数。"
        case .nutrition: "饮食日记会整理餐别、份量与营养。"
        case .trends: "有了真实的记录，才能看见自己的节奏。"
        }
    }
}

struct JournalLandingView: View {
    let kind: JournalKind
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                SectionEyebrow(text: "LEANORA / \(kind.title)")
                Text(kind.headline).font(.system(.largeTitle, design: .serif, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("screen.\(kind.rawValue)")
                Divider()
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: kind.symbol).font(.system(size: 42, weight: .light))
                        .foregroundStyle(LeanoraTheme.accent).accessibilityHidden(true)
                    Text(kind.empty).font(.title3.weight(.semibold))
                    Text(kind.detail).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(.vertical, 24)
                NavigationLink { JournalGuideView(kind: kind) } label: {
                    HStack { Text("了解\(kind.title)日记"); Spacer(); Image(systemName: "arrow.right") }
                        .frame(minHeight: 48)
                }.accessibilityIdentifier("guide.\(kind.rawValue)")
                NavigationLink("设置单位与目标") { PreferencesEditorView() }
                    .font(.subheadline).frame(minHeight: 44)
            }.padding(26)
        }.background(LeanoraTheme.canvas)
            .navigationTitle(kind.title).navigationBarTitleDisplayMode(.inline)
    }
}

struct JournalGuideView: View {
    let kind: JournalKind
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("先了解，\n再按自己的节奏来。")
                    .font(.system(.title, design: .serif, weight: .semibold))
                if kind == .training {
                    FeatureLine(symbol: "list.bullet", title: "计划与实际分开", detail: "模板描述打算怎么练，训练日记留下实际完成的内容。")
                    FeatureLine(symbol: "timer", title: "重量、次数与时间", detail: "力量与计时动作各有适合的记录方式，不必都换算成同一种数字。")
                } else if kind == .nutrition {
                    FeatureLine(symbol: "scalemass", title: "份量先说清楚", detail: "克、份或杯需要明确换算，营养数据才有可比性。")
                    FeatureLine(symbol: "questionmark.circle", title: "未知就是未知", detail: "只知道热量时，蛋白质、脂肪和碳水可以留空。")
                } else {
                    FeatureLine(symbol: "calendar", title: "看长期，也看来源", detail: "单次变化不代表长期趋势；不同来源的数据需要清楚标记。")
                    FeatureLine(symbol: "heart", title: "健康访问可选", detail: "可以先在「我的」中设置 Apple Health 访问范围。")
                }
            }.padding(26)
        }.background(LeanoraTheme.canvas).navigationTitle("\(kind.title)日记")
    }
}
