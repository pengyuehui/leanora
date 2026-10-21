# Leanora 0.2.0（2）发行候选

2026-10-21；基线 `df48c65` 后补齐运营资料并完成发行签名。App ID `ai.leanora.fitness`，团队/运营者 Manyao Li，Team ID `8ZP3NMT2A8`，支持邮箱 `pengyuehui@gmail.com`。

## 可审查的交付物

| 交付物 | 路径/状态 |
|---|---|
| 最终签名 Archive | `app/build/ReleaseCandidate/Leanora-0.2-Fitness-Privacy-Signed.xcarchive`；已成功 |
| App Store Connect 发行 IPA | `app/build/Exports/Leanora-0.2-Fitness-AppStore/Leanora.ipa`；已成功，尚未上传 |
| 签名/权限/摘要审计 | [fitness-appstore-ipa-audit.json](fitness-appstore-ipa-audit.json) |
| 原生隐私页返回引导 | [XCTest 摘要](fitness-privacy-ui-summary.json)；1 方法通过，未重跑全部 134 方法 |
| 完整政策源与网页 | [Markdown](../privacy-policy.md)、[HTML](../privacy-policy.html)；本机浏览器预览通过 |
| 公开网址核验 | [privacy-public-check.json](privacy-public-check.json)；HTTPS/浏览器连接失败 |

## 签名与发布范围

用户确认处理最新版开发者协议后，Xcode 为正式 App ID 获得匹配描述文件并签名成功。发行导出为 `app-store-connect`、`destination=export`；Apple Distribution 签名完整校验通过，Team/Bundle ID 一致，Store 描述文件无设备限制且 `get-task-allow=false`。HealthKit 与 background-delivery 权限均存在；包内的运营者、邮箱和政策 URL 与用户提供值一致，测试启动/失败注入字符串未进入发行二进制。见 [原始成功导出日志](fitness-appstore-export.log)。

首次准备上传为该团队内部 TestFlight 候选时，命令在执行前被自动审批拒绝，理由为缺少明确上传授权。用户随后明确回复“批准本次内部 TestFlight 上传”，同一操作获准执行；没有在授权前绕过审批。

实际上传前检查返回 `App record with bundle identifier "ai.leanora.fitness" not found on App Store Connect`，见 [原始上传日志](fitness-internal-upload.log)。Xcode Organizer 的内部 TestFlight 流程已打开创建应用记录表单，显示 Name `Leanora`、SKU/Bundle ID `ai.leanora.fitness`；尚无创建成功或上传成功证据。此前一次 UI 操作被自动审批服务的用量限制拦截，这属于审批服务不可用，不是安全拒绝。恢复后继续核对 UI 状态，不将未完成操作算作成功。

服务端 Validate、上传处理与安装验收不等于本地发行签名校验，仍按发布清单执行。物理设备与专业内容验收没有用模拟器替代。

## 政策发布

已按用户确认的运营者与支持邮箱更新 App、完整 Markdown 和 HTML，在线链接使用 `https://leanora.ai/`。核验时 web open 无法访问、curl 返回 TLS `SSL_ERROR_SYSCALL`、受控浏览器返回 `ERR_CONNECTION_CLOSED`；这些结果只说明当前客户端无法确认公开页面，不据此断言所有地区均无法访问。

`app/docs/privacy-policy.html` 为无 JavaScript/远程资源的独立页面，可部署为该网址返回的 HTML。它从 Markdown 生成，执行 `python3 app/scripts/render_privacy_policy.py` 可重建；本机浏览器已检查正文、章节和联系链接。需要恢复该 HTTPS 地址的外部访问并确认实际公开内容；当前没有部署凭据或站点代码，未修改线上站点。

## 重现候选导出

从已签名 Archive 执行 `bash app/scripts/export_testflight_candidate.sh <archive> <不存在的导出目录>`。脚本会使用已配置团队的自动签名资源，仅导出本地 IPA；不会发起上传。
