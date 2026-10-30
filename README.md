# Leanora

原生 iPhone 训练与饮食记录 App，支持 Apple Health，使用 SwiftUI、SwiftData 与 Apple 系统 SDK 独立实现。

- 自由训练、训练模板与周计划、逐组实际值、上次表现、历史再练、超级组与计时恢复。
- 动作收藏与最近使用、882 个动作的离线图示、4 套原创范例计划和 8 篇记录指南。
- 500 条来源食品（209 个中文名）、收藏/最近/分类检索、份量与营养快照、组合餐按份数记录。
- 6 套原创食物搭配、8 篇饮食记录指南、快捷热量、餐次复制和身体记录。
- HealthKit 增量读取、逐组件幂等写入、来源管理、删除抑制与备份恢复核对。
- JSON/CSV 导出、预检导入、独立数据清理及隐私说明。

打开 `app/ios/Leanora.xcodeproj`，选择 **Leanora** Scheme。最低 iOS 18，当前工程使用 Swift 6；构建验证使用 Xcode 27.1。正式 Bundle ID 为 `ai.leanora.fitness`。

核心测试：

```sh
swift test --package-path app --scratch-path app/build/SwiftPM --disable-swift-testing
```

运行、架构和构建步骤见 [应用 README](app/README.md)。功能覆盖、原始失败与修复后复测口径见 [验收报告](app/docs/qa/release-acceptance.md)，签名及 TestFlight 状态见 [发行候选记录](app/docs/qa/release-submission.md)。模拟器结果不替代物理设备验收。

`docs/plans/` 为开发计划，`analysis/` 为功能研究，`tools/rea/` 仅保留开发工具依赖清单。第三方研究源码、安装包、本机数据库、签名私钥、IPA 与构建缓存不提交到仓库。应用与内容来源见 [来源清单](app/docs/content-provenance.md)。

项目源码与原创训练内容按 [MIT 许可证](LICENSE) 开源。第三方动作图片、开发工具和食品数据遵循各自许可证，动作图示署名见 [第三方内容说明](app/THIRD_PARTY_NOTICES.md)。
