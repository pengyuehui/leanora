# App Store 1.1（5）送审记录

更新：2026-10-26。**Leanora Fitness 1.1（5）已正式提交 App Review，Apple 显示“等待审核”。提交时间为 11:15（Asia/Shanghai），审核通过后仍需手动发布。** 10 月 23 日上传因网络中断失败；10 月 26 日复用原 Archive 重试，11:01 Apple 确认上传成功，后续二进制验证、符号及审核提交均已在门户核验。

| 项目 | 核验结果 |
| --- | --- |
| 应用 / 团队 | Leanora Fitness；`6825234654`；`ai.leanora.fitness`；Manyao Li / `8ZP3NMT2A8` |
| 版本 / 构建 | 1.1（5）；已有 1.0 页面显示“可分发”，没有撤回原版本 |
| 更新内容 | 882 个动作，1765 张离线指导图片，详情、选择与训练中的指导入口，以及新增搜索筛选 |
| 兼容性 | 原 100 个动作字段和 ID 保留；不新增数据迁移，不改变业务备份 |
| 签名 | Apple Distribution，深度严格核验通过；Store profile；get-task-allow=false；HealthKit 和 background-delivery 权限存在 |
| 发行 IPA | 75,318,681 字节；全部 1765 张图片逐文件哈希匹配，三个完整许可/署名文件随包存在 |
| 商店文案 | 中英文介绍、更新说明和审核指引保存；重新加载并切换语言后与本地来源逐字一致 |
| Apple 接收 | 2026-10-26 11:01 上传成功；二进制“已验证”、包含符号“是”、非豁免加密“否”；Apple 侧 HealthKit 权限正确 |
| 构建关联 | 1.1（5）；Apple 构建 ID `635e9230-8998-48cf-98a4-389e25f2753b`；审核提交详情显示该版本和构建 |
| 正式送审 | 2026-10-26 11:15；1 个项目；提交 ID `8d6b5956-788d-4d18-ac91-510d4a7b708d`；等待审核 |
| 网站 | 独立健身政策和支持页 HTTPS 200；页面包含健身内容、运营主体和支持邮箱 |
| 隐私 / 商业设置 | 沿用已发布的“不收集数据”、免费及销售范围设置；本次不更改这些答案或设置 |
| 发布方式 | 审核后手动发布；没有执行自动公开发布 |

[Apple 审核详情](https://appstoreconnect.apple.com/apps/6825234654/distribution/reviewsubmissions/details/8d6b5956-788d-4d18-ac91-510d4a7b708d) · [等待审核凭据](appstore-1.1-5-waiting-review-20261026.png) · [Apple 二进制验证凭据](appstore-1.1-5-validated-20261026.png)。接下来等待 Apple 审核结果；本次不将“等待审核”写成批准或已上架。

## 构建来源与验证边界

应用 Swift 源码和资源来自已提交的 `944bec9a9be4eab8485a5e8b3ef43d3310e3ad88`；只覆盖版本号、构建号及本次商店文案。从独立源码快照签名构建，工作区原有未提交 `Localizable.xcstrings` 提取改动完整保留，没有纳入本次发行来源。

动作库此前的 104 项基础测试（0 失败、2 项跳过）及四个界面场景通过，详见[动作库验收](exercise-library/README.md)。本次业务源码没有变更，未声称重新执行全部功能测试；另行核验了实际发行包、图标、政策链接、图片、署名、签名和权限。[发行核验记录](appstore-1.1-5-distribution-audit-20261023.json)中的 IPA 摘要只对应本地发行导出；上传从相同 Archive 独立导出，不混称为上传传输包摘要。

没有新增视频或全量中文翻译。专业内容审定、最低系统物理设备、真实 VoiceOver 及背景/锁屏健康操作仍按[发布清单](../release-checklist.md)记录，不以 Apple 接收或送审替代这些验收。

## 内容许可和资料保护

Free Exercise DB 数据/照片使用 The Unlicense，Workout Guide / Everkinetic 的选定插图保持 CC BY-SA 4.0、署名及完整许可；没有加入 openGym 的受限 Gym visual 素材。说明已写入审核备注，完整清单见[第三方声明](../../THIRD_PARTY_NOTICES.md)。图片只随包读取，没有向第三方请求图片、上传健康信息或增加权限。

审核联系信息沿用 Apple 现有保存值。实际电话号码、私人账号资料、认证信息和完整发行日志不进入公开仓库。公开网站已在 10 月 26 日再次核验，见[网页检查记录](fitness-website-check-20261026.json)。[最新上传回执](appstore-1.1-5-upload-20261026.json)及[发行状态](../../store/app-store-release-1.1-5-20261026.json)记录后续进度。
