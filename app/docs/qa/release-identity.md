# 正式发布身份与签名检查

2026-10-21；基线 `16e8595` 后的发布配置更新。

| 配置 | 值与依据 |
|---|---|
| 团队名称 | 用户指定 Manyao Li |
| Team ID | `8ZP3NMT2A8`；本机 Xcode 的 `IDEProvisioningTeamByIdentifier` 与同名 Apple Development 公钥证书的 OU 一致 |
| 正式 Bundle ID | 用户指定 `ai.leanora.fitness`；App、单元及 UI 测试的 Debug/Release 配置和工程生成脚本同步更新 |
| 应用版本 | 0.2.0（2） |
| 当前结果 | 新标识的真实 HealthKit 模拟器闭环与未签名 Release Archive 通过，正式签名尚未成功 |

团队显示名称与 Team ID 是不同字段；Apple 将 Team ID 定义为 10 字符成员标识，见 [官方说明](https://developer.apple.com/help/glossary/team-id/)。没有读取/导出私钥，没有把其他团队或其他应用的描述文件用于此 App。

## 验证

- 工程生成脚本 Ruby 语法检查通过；解析工程确认三个 target、各两种配置均为指定的 Team ID 和相应 Bundle ID。
- 使用新标识 `ai.leanora.fitness` 在 iOS 27.1 模拟器独立安装，实际系统授权、受限历史、65.4 kg 写入和重复同步检查通过。结果见 [XCTest 摘要](fitness-bundle-health-summary.json)；旧 134 项覆盖证据仍保留，新标识复测不增加独立方法数量。
- 正式标识的未签名 Release Archive 构建通过，包审计见 [fitness-release-audit.json](fitness-release-audit.json)。它不是可分发 TestFlight 包。
- 使用现有签名资源 Archive 报无匹配描述文件；再加 `-allowProvisioningUpdates` 请求 Xcode 获取描述文件，Apple 返回 `Unable to process request - PLA Update available`，要求在开发者账号接受最新 Program License Agreement。见 [原始签名日志](fitness-provisioning-attempt.log)。这是 Apple 账号门槛，不是构建源码错误；没有上传。

## 继续发布所需操作

账号持有人前往 [Apple Developer 账号](https://developer.apple.com/account/) 处理最新协议后，再为 `ai.leanora.fitness` 核实 HealthKit/background-delivery 能力与描述文件，生成签名 Archive、Validate 并按发布清单完成 TestFlight。政策公开 URL、支持邮箱及实际运营主体尚待提供；团队名称不自动当作政策运营主体。物理设备与专业内容门槛继续保留。

## 已有数据边界

更改 Bundle ID 会使用独立应用沙盒，不能自动读取旧开发版 `app.leanora.dev` 的资料；需要保留的数据应先在旧版导出 JSON，再在正式标识版本导入。Health 样本来源也随应用标识区分，正式版本只清理当前来源副本，旧开发版样本不被自动删除。

业务备份格式 `app.leanora.backup`、稳定 Health 同步标识 `app.leanora.<业务 UUID>.<组件>` 保持不变，它们是版本化数据合同，不是应用 Bundle ID。恢复后仍先核对、再由用户明确选择历史导出。
