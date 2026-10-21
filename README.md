# Leanora

原生 iPhone 训练与饮食记录 App，支持 Apple Health，使用 SwiftUI、SwiftData 与 Apple 系统 SDK 独立实现。

- 训练模板、周计划、逐组实际值、超级组、休息计时、暂停恢复与历史趋势。
- 离线食品搜索、份量与营养快照、快捷热量、餐次复制和身体记录。
- HealthKit 增量读取、逐组件幂等写入、来源管理、删除抑制与备份恢复核对。
- JSON/CSV 导出、预检导入、独立数据清理及隐私说明。

打开 `app/ios/Leanora.xcodeproj`，选择 **Leanora** Scheme。最低 iOS 18，当前工程使用 Swift 6；构建验证使用 Xcode 27.1。正式 Bundle ID 为 `ai.leanora.fitness`。

核心测试：

```sh
swift test --package-path app --scratch-path app/build/SwiftPM --disable-swift-testing
```

运行、架构和构建步骤见 [应用 README](app/README.md)。功能覆盖、原始失败与修复后复测口径见 [验收报告](app/docs/qa/release-acceptance.md)，签名及 TestFlight 状态见 [发行候选记录](app/docs/qa/release-submission.md)。模拟器结果不替代物理设备验收。

`docs/plans/` 为开发计划，`analysis/` 为功能研究，`tools/rea/` 仅保留开发工具依赖清单。第三方研究源码、安装包、本机数据库、签名私钥、IPA 与构建缓存不提交到仓库。应用与内容来源见 [来源清单](app/docs/content-provenance.md)。
