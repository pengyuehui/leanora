import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionEyebrow(text: "隐私与数据说明 · 2026.10.21")
                Text("隐私与数据")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("privacy.title")
                FeatureLine(symbol: "iphone", title: "本机保存", detail: "训练、逐组明细、模板、饮食、身体数据与目标保存在本机，无需账号。数据库、健康缓存和升级恢复副本采用设备文件保护，并排除系统自动云备份。")
                FeatureLine(symbol: "heart", title: "健康访问按需开启", detail: "你选择读入或写入身体、训练、饮食数据，也可只读日常步数和活动能量。首次读入最近 90 天；健康写入只包含允许的已知组件，不推算心率或训练消耗。系统不会向 App 明确透露读取权限是否被拒绝。")
                FeatureLine(symbol: "hand.raised", title: "没有广告或追踪", detail: "不上传健康资料，不接入广告、第三方分析或 AI 服务，也不使用 CloudKit 同步。")
                FeatureLine(symbol: "externaldrive", title: "手动备份与导出", detail: "「数据管理」提供 JSON 备份、预检导入和 CSV 记录表。文件含敏感资料且未加密，保存位置由你选择；不包含 Apple Health 缓存或设备同步任务。请在卸载前导出需要保留的资料。")
                FeatureLine(symbol: "slider.horizontal.3", title: "随时调整", detail: "单位和目标可在「我的」修改。健康与通知权限可在系统中撤回。导入不会自动把记录重新写入 Apple Health。")
                FeatureLine(symbol: "trash", title: "三种独立清理", detail: "可单独清除健康导入缓存、清除本机资料与恢复副本，或删除本 App 写入的健康副本。停止同步保留历史副本；其他来源的健康数据不会被删除。你另行导出的文件需在文件 App 中管理。")
                VStack(alignment: .leading, spacing: 12) {
                    Text("运营主体：Manyao Li").font(.headline)
                    if let policyURL = URL(string: "https://leanora.ai/") {
                        Link("隐私政策网站", destination: policyURL).frame(minHeight: 44)
                    }
                    if let supportURL = URL(string: "mailto:pengyuehui@gmail.com") {
                        Link("联系支持：pengyuehui@gmail.com", destination: supportURL).frame(minHeight: 44)
                    }
                }
                Divider()
                Text("此说明对应 Leanora 0.2，由 Manyao Li 运营。App 不提供医疗诊断或个体化治疗建议。")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(26)
        }.background(LeanoraTheme.canvas)
            .navigationTitle("隐私与数据").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
    }
}
