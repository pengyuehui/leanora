# Leanora 0.2 发布清单

源码和本机候选构建不等于已交付 TestFlight。状态记录与证据见 [release-acceptance.md](qa/release-acceptance.md)。

## 构建与来源

- [x] Swift 6，最低 iOS18，原生 HealthKit/SwiftData，正式 Bundle ID 配置为 `ai.leanora.fitness`。
- [x] Apple 系统 SDK 以外无运行时依赖，独立实现，未复制 OpenGym/训记/薄荷代码、媒体或目录。
- [x] 100 动作、300 食品，固定 ID、来源、单位与快照。
- [x] 健康用途说明、隐私清单、App 内隐私入口与政策源文件同步更新。
- [ ] 专业教练/营养内容复核签名、品牌确认。

## 功能与数据

- [x] 本机训练/饮食/身体闭环、版本化 JSON、CSV 与安全转义。
- [x] 单独清理缓存/本机/健康副本，明确删除范围与恢复后门槛。
- [x] 同步队列、逐组件授权与失败、版本幂等、删除抑制、备份核对。
- [x] 真实 SwiftData + 传输适配边界测试及容量测试。
- [ ] 最低/当前稳定系统物理 iPhone 的双向样本、背景/锁屏、通知与文件保护。
- [ ] 多来源统计与时区/夏令时真机核对；VoiceOver 实际朗读顺序及操作。

## App Store Connect / TestFlight

- [x] 发布者指定正式 Bundle ID `ai.leanora.fitness` 及 Manyao Li 团队；本机 Xcode 与证书 OU 核实 Team ID `8ZP3NMT2A8`，工程及生成脚本已配置。
- [x] 账号持有人已处理 Apple 最新 Program License Agreement，Xcode 后续请求成功。
- [x] 获得正式 Bundle ID 的开发/发行描述文件，发行包包含 HealthKit/background-delivery 权限。
- [x] 发布者确认运营主体 Manyao Li、支持邮箱 `pengyuehui@gmail.com`、政策网址 `https://leanora.ai/`；App 与政策源文件已更新。
- [ ] 公开政策的 HTTPS 可访问性及实际内容核验；本机浏览器返回 `ERR_CONNECTION_CLOSED`，政策 HTML 已准备。
- [x] Xcode 签名 Archive、App Store Connect 发行 IPA 导出、签名与权限检查通过。
- [ ] App Store Connect 服务端 Validate App 及审核隐私报告确认。
- [ ] App Store Connect 创建应用与测试组，填写中文描述、支持 URL、年龄分级、出口合规与隐私标签。
- [ ] 根据实际构建确认无服务器收集，声明 Health 数据用途；不把本机访问误填成向开发者收集。
- [ ] 上传正式签名构建，等待处理/可能的 Beta Review，安装到上述物理设备。
- [ ] TestFlight 端到端走查通过并记录构建号、验收人及日期。

当前候选为 0.2.0（2）；用户已批准内部上传，实际执行后 Apple 返回缺少 `ai.leanora.fitness` 的应用记录。Xcode 已打开创建表单，尚无创建或上传成功证据。详见 [候选记录](qa/release-submission.md)。

## 审核演示路径

无需账号，完成引导可跳过全部权限。训练：新建模板 → 添加动作/目标 → 开始 → 编辑实际组值 → 完成组/休息 → 暂停/恢复 → 完成 → 历史修改/容量。饮食：选择日期/餐别 → 搜索最近/基础/自定义食物 → 份量 → 保存；快捷热量不推算宏量营养素。身体：新增两次测量 → 趋势。健康：按需系统请求 → 状态/来源 → 部分失败重试 → 停止；恢复备份不会自动批量导出。

## Post-Deploy Monitoring & Validation

首批 TestFlight 由发布负责人观察 48 小时，另在每次权限撤回、锁屏和恢复场景后检查同步状态页：健康信号为队列收敛、已知组件只一份、游标继续推进且外部缓存保留。失败信号是 pending 持续增加、同组件重复样本、恢复资料自动覆盖或本机记录丢失。出现数据丢失/重复同步立即停止扩大测试并关闭自动同步，保存 JSON 与脱敏步骤，在修复前不引导用户再次导出历史。只使用用户同意提交的脱敏诊断和 TestFlight 崩溃信息；不增设上传健康明细的日志或分析服务。

回退使用上一个通过的应用构建，保留数据库与备份，不执行破坏性降级迁移。当前 schema 没有新增数据库实体，健康设备状态为可选 enum case；旧构建可能无法读取新运行时状态，不支持直接用 0.1 打开 0.2 的健康状态库，必要时由 0.2 导出业务 JSON 后在隔离库恢复。
