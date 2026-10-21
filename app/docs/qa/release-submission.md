# Leanora 0.2.0（2）发行候选

2026-10-21；基线 `df48c65` 后补齐运营资料并完成发行签名。Bundle ID `ai.leanora.fitness`，团队/运营者 Manyao Li，Team ID `8ZP3NMT2A8`，支持邮箱 `pengyuehui@gmail.com`。

## 可审查的交付物

| 交付物 | 路径/状态 |
|---|---|
| 最终签名 Archive | `app/build/ReleaseCandidate/Leanora-0.2-Fitness-Privacy-Signed.xcarchive`；已成功 |
| App Store Connect 发行 IPA | `app/build/Exports/Leanora-0.2-Fitness-AppStore/Leanora.ipa`；本机导出成功；同一 Archive 已经 Xcode 内部分发流程重新导出并上传 |
| App Store Connect 应用记录 | `Leanora Fitness`；Apple App ID `6825234654`；主语言 `zh-Hans`；创建成功 |
| 内部 TestFlight 上传 | 0.2.0（2）；Apple 返回 `UPLOAD SUCCEEDED with no errors`，接收时状态 `PROCESSING`；[成功截图](fitness-testflight-upload-success.png)、[结构化凭据](fitness-testflight-upload.json)、[脱敏状态摘录](fitness-testflight-upload-status.log) |
| 签名/权限/摘要审计 | [fitness-appstore-ipa-audit.json](fitness-appstore-ipa-audit.json) |
| 原生隐私页返回引导 | [XCTest 摘要](fitness-privacy-ui-summary.json)；1 方法通过，未重跑全部 134 方法 |
| 完整政策源与网页 | [Markdown](../privacy-policy.md)、[HTML](../privacy-policy.html)；本机浏览器预览通过 |
| 公开网址核验 | [privacy-public-check.json](privacy-public-check.json)；HTTPS/浏览器连接失败 |

## 签名与发布范围

用户确认处理最新版开发者协议后，Xcode 为正式 App ID 获得匹配描述文件并签名成功。发行导出为 `app-store-connect`、`destination=export`；Apple Distribution 签名完整校验通过，Team/Bundle ID 一致，Store 描述文件无设备限制且 `get-task-allow=false`。HealthKit 与 background-delivery 权限均存在；包内的运营者、邮箱和政策 URL 与用户提供值一致，测试启动/失败注入字符串未进入发行二进制。见 [原始成功导出日志](fitness-appstore-export.log)。

首次准备上传为该团队内部 TestFlight 候选时，命令在执行前被自动审批拒绝，理由为缺少明确上传授权。用户随后明确回复“批准本次内部 TestFlight 上传”，同一操作获准执行；没有在授权前绕过审批。

首次实际上传前检查返回 `App record with bundle identifier "ai.leanora.fitness" not found on App Store Connect`，见 [原始上传日志](fitness-internal-upload.log)。随后使用 `Leanora` 创建记录被 Apple 拒绝，原因是应用名称已被占用。用户明确选择新的商店名称 `Leanora Fitness`；仅调整商店记录，安装显示名仍为 `Leanora`，Bundle ID 和候选二进制不变。

通过 Xcode Organizer 的 **TestFlight Internal Only** 流程，以名称 `Leanora Fitness`、SKU/Bundle ID `ai.leanora.fitness`、主语言简体中文（`zh-Hans`）创建成功，Apple 返回 App ID `6825234654`。2026-10-21 15:55:42（UTC+8），界面显示 `Leanora 0.2.0 (2) uploaded`；分发日志同时返回 `Upload succeeded for archive Leanora` 和 `UPLOAD SUCCEEDED with no errors`。上传选项确认 `testFlightInternalTestingOnly=true`、`uploadSymbols=true`；该工作流开启自动管理版本/构建号，最终界面确认上传版本仍为 0.2.0（2）。

接收时 Apple 状态为 `PROCESSING`；尚未核验处理完成、内测组可安装或物理设备安装。记录入口为 [App Store Connect](https://appstoreconnect.apple.com/apps/6825234654/testflight)。本次未修改业务源码或重建原 Archive，不重复运行功能测试，原测试口径保持不变。

此前一次 UI 操作被自动审批服务的用量限制拦截，这属于审批服务不可用，不是安全拒绝。恢复后继续核对 UI 状态，不将未完成操作算作成功。失败日志保留；成功分发的完整日志含账号/会话信息，仅在本机保留，仓库只保存白名单字段、状态行、原始日志摘要及截图。

上传成功不等于独立运行 Validate App、Apple 后续处理完成或安装验收；这些状态仍分别按发布清单执行。物理设备与专业内容验收没有用模拟器替代。

## 政策发布

已按用户确认的运营者与支持邮箱更新 App、完整 Markdown 和 HTML，在线链接使用 `https://leanora.ai/`。核验时 web open 无法访问、curl 返回 TLS `SSL_ERROR_SYSCALL`、受控浏览器返回 `ERR_CONNECTION_CLOSED`；这些结果只说明当前客户端无法确认公开页面，不据此断言所有地区均无法访问。

`app/docs/privacy-policy.html` 为无 JavaScript/远程资源的独立页面，可部署为该网址返回的 HTML。它从 Markdown 生成，执行 `python3 app/scripts/render_privacy_policy.py` 可重建；本机浏览器已检查正文、章节和联系链接。需要恢复该 HTTPS 地址的外部访问并确认实际公开内容；当前没有部署凭据或站点代码，未修改线上站点。

## 重现候选导出

从已签名 Archive 执行 `bash app/scripts/export_testflight_candidate.sh <archive> <不存在的导出目录>`。脚本会使用已配置团队的自动签名资源，仅导出本地 IPA；不会发起上传。
