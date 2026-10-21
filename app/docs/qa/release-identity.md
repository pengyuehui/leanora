# 正式发布身份与签名检查

2026-10-21；基线 `16e8595` 后的发布配置更新。

| 配置 | 值与依据 |
|---|---|
| 团队名称 | 用户指定 Manyao Li |
| Team ID | `8ZP3NMT2A8`；本机 Xcode 的 `IDEProvisioningTeamByIdentifier` 与同名 Apple Development 公钥证书的 OU 一致 |
| 正式 Bundle ID | 用户指定 `ai.leanora.fitness`；App、单元及 UI 测试的 Debug/Release 配置和工程生成脚本同步更新 |
| 应用版本 | 0.2.0（2） |
| 商店记录 | 用户选择 `Leanora Fitness`；Apple App ID `6825234654`；主语言简体中文；安装显示名仍为 `Leanora` |
| 当前结果 | 新标识的真实 HealthKit 模拟器闭环、正式签名 Archive 与发行 IPA 导出通过；内部 TestFlight 上传成功，接收时 Apple 状态 `PROCESSING` |

团队显示名称与 Team ID 是不同字段；Apple 将 Team ID 定义为 10 字符成员标识，见 [官方说明](https://developer.apple.com/help/glossary/team-id/)。没有读取/导出私钥，没有把其他团队或其他应用的描述文件用于此 App。

## 验证

- 工程生成脚本 Ruby 语法检查通过；解析工程确认三个 target、各两种配置均为指定的 Team ID 和相应 Bundle ID。
- 使用新标识 `ai.leanora.fitness` 在 iOS 27.1 模拟器独立安装，实际系统授权、受限历史、65.4 kg 写入和重复同步检查通过。结果见 [XCTest 摘要](fitness-bundle-health-summary.json)；旧 134 项覆盖证据仍保留，新标识复测不增加独立方法数量。
- 正式标识的未签名 Release Archive 构建通过，包审计见 [fitness-release-audit.json](fitness-release-audit.json)。它不是可分发 TestFlight 包。
- 第一次使用现有签名资源 Archive 报无匹配描述文件；再加 `-allowProvisioningUpdates` 请求 Xcode 获取描述文件，Apple 返回 `Unable to process request - PLA Update available`。见 [历史签名失败日志](fitness-provisioning-attempt.log)，保留原始结果。
- 用户随后确认已处理最新协议，重试成功。最终包含运营者联系方式的 Archive 通过，发行 IPA 使用 `Apple Distribution: Manyao Li (8ZP3NMT2A8)`，正式 Store profile、HealthKit/background-delivery 权限及 `get-task-allow=false` 核验通过。见 [发行审计](fitness-appstore-ipa-audit.json) 和 [后续候选记录](release-submission.md)。

## 继续发布所需操作

运营主体已由用户明确确认为 Manyao Li，邮箱 `pengyuehui@gmail.com`，政策网址 `https://leanora.ai/`。App、Markdown 与可部署 HTML 已同步。公开网址在本机浏览器/HTTPS 请求中连接失败，尚未确认线上内容。用户已明确批准内部上传；补齐应用记录并解决名称占用后，0.2.0（2）内部上传成功，详见 [上传凭据](fitness-testflight-upload.json)。后续处理、安装、独立服务端验证、物理设备与专业内容门槛继续保留。

## 已有数据边界

更改 Bundle ID 会使用独立应用沙盒，不能自动读取旧开发版 `app.leanora.dev` 的资料；需要保留的数据应先在旧版导出 JSON，再在正式标识版本导入。Health 样本来源也随应用标识区分，正式版本只清理当前来源副本，旧开发版样本不被自动删除。

业务备份格式 `app.leanora.backup`、稳定 Health 同步标识 `app.leanora.<业务 UUID>.<组件>` 保持不变，它们是版本化数据合同，不是应用 Bundle ID。恢复后仍先核对、再由用户明确选择历史导出。
