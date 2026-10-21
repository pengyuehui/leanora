# App Store 1.0（3）提交准备

更新：2026-10-21。用户已明确要求“构建并提交 App Store”。**归档构建完成；发行 IPA 导出失败，尚未上传或提交 App Review。**

| 项目 | 已核验结果 |
|---|---|
| 应用 | Leanora Fitness；Apple App ID `6825234654` |
| Bundle / Team | `ai.leanora.fitness` / Manyao Li，`8ZP3NMT2A8` |
| 商店版本 | 既有记录为 iOS 1.0，准备提交；工程及生成脚本更新为 `1.0`，build `3` |
| 新版图标 | 已接入资源目录，本次资源编译成功，源文件摘要与素材包一致 |
| Archive | `app/build/ReleaseCandidate/Leanora-1.0-3-AppStore-Privacy-Signed.xcarchive`；修正旧版本隐私页文案后构建成功，当前为 Apple Development 签名 |
| 签名检查 | 获得系统信任服务访问后 `codesign --verify --deep --strict` 通过；初始受限检查的信任错误另行保留说明 |
| 权限 | HealthKit、background-delivery、Team 与应用标识匹配；最低 iOS18，iPhone |
| 发行导出 | 失败：`No Accounts` / `No signing certificate "iOS Distribution" found`，当前没有可提交的发行 IPA |
| 上传 / 审核提交 | 未执行；不将 Archive 成功当作发行或提审成功 |

结构化结果见 [build audit](appstore-1.0-3-build-audit.json)，原始导出失败日志分别见 [首次](appstore-1.0-3-export-failure.log)、[最终归档重试](appstore-1.0-3-privacy-export-failure.log)。归档/开发缓存不提交到仓库。此前已上传的 0.2.0（2）仍为内部 TestFlight 构建，不能替代此次正式 App Store 候选。

## 当前外部状态

- Chrome 的既有 App Store Connect 页面初始显示 Manyao Li 团队和 `Leanora Fitness iOS 1.0 准备提交`。版本页渲染失败，重新加载后进入 `login?...authResult=FAILED`。未读取其他 App 的设置，未从缓存或日志提取认证令牌绕过登录。
- 打开 Xcode 时系统返回 Mac 已锁定、自动解锁失败，需要用户手动解锁。解锁后先重新检查账号/签名状态，不直接假定必须重建证书。
- Apps 页面显示新版 Paid Applications Schedule 待接受提示，已请求账号持有人处理。是否阻止最终选择的分发方案，需恢复登录后核对；代理没有代为接受协议。
- 用户指定的 `https://leanora.ai/` 当前 HTTPS 请求返回 `SSL_ERROR_SYSCALL`、HTTP 000；web 工具也无法读取。只据此记录当前客户端无法核验公开政策，不断言全球不可用。已请求用户选择：修复该网址，或同意使用已公开 GitHub 政策和产品联系页面。未擅自替换已指定的政策入口。

## 已准备的资料

中文/英文文案、两套各 7 张中文展示图、JSON 元数据和图标均通过本地检查，见 [素材包](../../store/README.md)。版本说明已改为“首个版本”，不将正式 App 标作测试版。素材制作的真实页面及功能证据沿用此前报告；此次仅修改版本和 build，未重跑全部 134 个功能方法。

[审核说明](../../store/review-notes.txt) 包含无需账号、可跳过健康权限、训练/饮食/身体/备份走查和真实数据边界。[提交草稿](../../store/submission-draft.json) 列出 1.0（3）的来源和待填项；未知审核电话、价格、分发地区、支持 URL 保持为空，不编造资料。实际审核电话仅填写到 Apple，不保存到公开仓库或公开截图。

## 恢复后执行

1. 用户解锁 Mac，并恢复 Chrome / Xcode 的 Apple 登录；核对 Manyao Li 团队与协议提示。
2. 确认可公开访问且内容匹配的隐私政策、支持入口。如果 App 内 URL 需要变更，更新源码并以新本地路径重新 Archive；build 3 尚未上传，可继续作为本次候选。
3. 使用 `export_testflight_candidate.sh` 向一个尚不存在的目录重试发行导出；核验 Apple Distribution、Store 描述文件、`get-task-allow=false`、HealthKit 权限和图标。当前开发签名归档不能直接当作已分发 IPA。
4. 使用 [正式上传选项](../../config/ExportOptions-AppStore-Upload.plist)：`destination=upload`、`testFlightInternalTestingOnly=false`、`manageAppVersionAndBuildNumber=false`、`uploadSymbols=true`。先验证最终包和资料，再实际上传。
5. 填写并保存商店元数据、上传截图、完成年龄分级/隐私/内容权利/审核联系等表单，核对价格与地区；对未知且必填的信息向用户集中补齐。
6. 等 Apple 处理完成，选择 1.0（3），添加审核并点击实际的 Submit for Review；以门户最终状态核验提交。计划采用审核后手动发布，不把加入草稿当作已送审。

最低/当前系统物理 iPhone、锁屏/后台、多来源及时区、VoiceOver 与专业内容复核没有在本次构建中被补做，仍保留在 [发布清单](../release-checklist.md)，不能宣称已通过。
