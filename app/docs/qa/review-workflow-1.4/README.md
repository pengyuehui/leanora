# Leanora 1.4 验证进度

2026-11-03，状态：核心通过，原生 UI 和发行流程等待本机环境恢复。

- Foundation：149 项，147 通过、2 项既有容量用例按配置跳过，0 失败。新增 11 项覆盖日期/DST、记录覆盖、动作类型、整批复制事务回滚、幂等重试和备份。最终日志 `app/build/v14-core-5.log`。
- 原生构建：Xcode 27.2（27B52），应用、核心测试与 UI 测试目标 `build-for-testing` 成功；`app/build/v14-build-3.log`。不能等同 UI 通过。
- 原生执行：Xcode 要求 CoreSimulator 1174.21.0，本机 1174.9.2，模拟器设备支持被禁用，UI 测试没有运行。尝试日志 `app/build/v14-ui-1.log`。Mac 锁定，首次启动组件更新尚不能处理。
- 资源：882 个动作/1765 张图片的哈希与来源验证通过；500 条食品（209 中文名）全部营养/份量与官方原 ZIP 核验，原 300 条值保持。两类原创指南各 12 篇已由核心测试验证可解码。
- 代码审查：correctness 与 adversarial 在主线程顺序执行；修正复制提交期间输入变更和从 Today 导航的返回栏问题。见 [review.json](review.json)。
- 发行：开发签名归档成功，不能作为发行可用证明。导出失败，Apple 工具报告 No Accounts、缺少团队匹配发行证书私钥；`app/build/v14-distribution-export-1.log`。未创建可上传 IPA，未上传或送审 1.4。
- 商店：双语介绍、推广文字、版本说明和审核指引已在本地准备并校验长度；仍保留 1.3 截图，未冒充 1.4 截图。Apple 网页登录过期，实时旧版本状态尚不可核对。

完整机器记录：[verification.json](verification.json)。发行准备：[app-store-release-1.4-8-20261103.json](../../../store/app-store-release-1.4-8-20261103.json)。开发计划：[1.4 计划](../../../../docs/plans/2026-11-03-001-feat-daily-review-reuse-plan.md)。

恢复顺序：解锁 Mac → Xcode 完成首次启动组件更新并恢复 Manyao Li 发行账号 → App Store Connect 登录 → 执行 `ReviewWorkflowTests`、截图及旧流程回归 → 检视实际截图并修复 → 从确定源码重建发行归档并导出审计 → 上传并确认 Apple VALIDATED → 按实际旧版本审核状态处理 1.4 送审。沿用审核后手动发布，不自动上架。

当前未声称最低 iOS 18 真机、真实 VoiceOver、真实 HealthKit 授权或专业教练/营养复核已完成。
