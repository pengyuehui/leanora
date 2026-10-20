import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionEyebrow(text: "隐私与数据说明 · 2026.10.20")
                Text("你的数据，\n始终属于你。")
                    .font(.system(.largeTitle, design: .serif, weight: .semibold))
                    .accessibilityIdentifier("privacy.title")
                FeatureLine(symbol: "iphone", title: "本机保存", detail: "动作、训练模板、周安排、已开始训练和目标保存在本机，无需账号。数据库和升级恢复副本采用设备数据保护，并排除系统自动云备份。逐组执行与饮食录入将在后续阶段提供。")
                FeatureLine(symbol: "heart", title: "健康访问按需开启", detail: "仅在你点击后向系统请求选定类型的访问。当前版本不读取、不写入健康记录。系统不会向 App 明确透露读取权限是否被拒绝。")
                FeatureLine(symbol: "hand.raised", title: "没有广告或追踪", detail: "不上传健康资料，不接入广告、第三方分析或 AI 服务，也不使用 CloudKit 同步。")
                FeatureLine(symbol: "externaldrive", title: "手动备份", detail: "「数据管理」提供 JSON 导出、预检和导入。导出的文件含敏感资料且未加密，保存位置由你选择；不包含 Apple Health 缓存或设备同步任务。请在卸载前导出需要保留的资料。")
                FeatureLine(symbol: "slider.horizontal.3", title: "随时调整", detail: "单位和目标可在「我的」修改。健康与通知权限可在系统中撤回。导入不会自动把记录重新写入 Apple Health。")
                Divider()
                Text("此说明对应 Leanora 0.1 的实际功能。新增记录或同步功能时，会更新数据用途与隐私说明。")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(26)
        }.background(LeanoraTheme.canvas)
            .navigationTitle("隐私与数据").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
    }
}
