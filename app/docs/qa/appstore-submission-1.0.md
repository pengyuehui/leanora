# App Store 1.0（4）已提交审核

更新：2026-10-22。**Leanora Fitness 1.0（4）已正式提交 App Review，Apple 状态为“等待审核”，重新加载后状态保持。尚未审核通过或公开上架。发布方式仍为审核通过后手动发布。**

| 项目 | 最终核验结果 |
|---|---|
| 应用 | Leanora Fitness；App ID `6825234654`；Bundle `ai.leanora.fitness` |
| 团队 | Manyao Li；`8ZP3NMT2A8` |
| 版本 / 构建 | 1.0（4）；Apple 构建 ID `5e2b2cfb-34cc-4f04-affe-b6a8183524a6` |
| 构建与签名 | Archive、发行导出及深度严格签名核验通过；Apple Distribution；Store profile 无设备列表，get-task-allow=false；HealthKit/background-delivery 正确 |
| 图标与链接 | Assets.car 与最终 Archive 一致，新图标源摘要不变；Release 二进制包含 `https://leanora.ai/fitness/privacy/` |
| Apple 二进制 | 正式上传 10:58:16 成功；服务端“已验证”、包含符号“是”；构建 4 版本关联刷新保持 |
| 公开政策 / 支持 | 两条 Fitness URL 有效 HTTPS、200，线上 HTML 与交付文件逐字节一致，主体/邮箱/正文及页面导航通过 |
| 商店资料 | 中英文政策网址、技术支持网址均已保存；两种介绍与本地来源逐字一致，重载/切换后保持；14 张中文截图沿用此前核验的上传 |
| 隐私答案 | “不收集数据”已发布，重载后仍显示发布者和预览；Apple 发布准确性及及时更新声明经用户当次确认后提交 |
| 价格与范围 | 免费；174 个国家/地区在发布时供应，中国大陆未供应；未来新增地区自动供应；审核后手动发布 |
| 审核资料 | 无需登录、审核说明及联系资料已保存；实际电话只交给 Apple |
| 正式送审 | 2026-10-22 11:16（Asia/Shanghai）；1 个项目，iOS App 1.0 / 1.0（4） |
| 提交 ID / 状态 | `af96310a-9852-4253-b731-56a6a0440dda`；等待审核，重载核验通过 |

[最新发行回执](../../store/app-store-release-1.0-4-20261022.json)、[签名与上传核验](appstore-1.0-4-distribution-audit-20261022.json)、[Apple 等待审核凭据](appstore-1.0-4-waiting-review-20261022.png)、[隐私发布凭据](appstore-privacy-published-20261022.png)。

## 网站与构建 4 的原因

用户修复域名后，原首页及原政策属于少儿围棋 Leanora AI，旧 `/support/` 也回退到围棋首页。为保留既有网站，健身政策和支持采用独立路径；用户通过 SCP 上传两份静态 HTML，代理未改动服务器、DNS 或围棋站点。

- 政策：[leanora.ai/fitness/privacy/](https://leanora.ai/fitness/privacy/)
- 支持：[leanora.ai/fitness/support/](https://leanora.ai/fitness/support/)

本次公共核验两页分别为 4,641、3,954 字节，SHA256 与本地交付来源一致。政策 `3db12abcbae561b71e8f8ff45f6ab4ae5e59361a6b15fb1715a4f989515d52cc`；支持 `02adce4a8d38c66167dc95aadec0a276e673fea9c82a854144b51cf4d9ed76bd`。详见 [公开网站核验](fitness-website-check-20261022.json)、[政策实际页面](fitness-policy-live-20261022.png)、[支持实际页面](fitness-support-live-20261022.png)。

1.0（4）将 App 内政策链接、源文档和双语介绍切换到相同路径；新候选经签名、上传及 Apple 验证后替代构建 3。此前 [构建 3 回执](../../store/app-store-release-20261022.json)、[停止保存点](../../store/stop-point-20261022.json) 和 [原缺项提示](appstore-review-blockers-20261022.png) 保留历史，不代表当前仍被阻塞。

## 验证边界与后续

本次更改仅为政策网址和构建号，没有重新执行全部 134 个功能方法。既有真机、锁屏/后台、多来源/时区、VoiceOver 和专业内容复核仍见 [发布清单](../release-checklist.md)，不能把 Apple 接收或等待审核当作这些验收通过。

本地验证 IPA 摘要只对应本地发行导出；上传从同一 Archive 重新导出，未采集传输包摘要。完整日志和二进制在忽略目录，公开回执仅含白名单状态行。实际审核电话、账号私人联系方式和认证信息均未公开。

接下来等待 Apple 审核结果。通过后按用户已选的手动发布方式处理；当前没有自动上架，也没有创建额外监控或定时任务。
