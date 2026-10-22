# App Store 1.0（3）提交准备

更新：2026-10-22。用户已明确要求“构建并提交 App Store”，并确认协议已处理、要求上传新图标和素材。**14 张中文截图、中英文商店文案与审核资料已保存到 Apple；新版图标所在的发行构建仍未上传，尚未提交 App Review。**

| 项目 | 已核验结果 |
|---|---|
| 应用 | Leanora Fitness；Apple App ID `6825234654` |
| Bundle / Team | `ai.leanora.fitness` / Manyao Li，`8ZP3NMT2A8` |
| 商店版本 | 既有记录为 iOS 1.0，准备提交；工程及生成脚本更新为 `1.0`，build `3` |
| 新版图标 | 已接入资源目录，本次资源编译成功，源文件摘要与素材包一致 |
| 截图 | 简体中文中屏 1206×2622、大屏 1320×2868 各 7 张，媒体管理页重新加载后均显示 7/10，顺序正确 |
| 商店文案 | 简体中文、英语（美国）的介绍/推广文本/关键词与本地源逐字一致；两种副标题、健康健美分类、版权已保存并重新进入页面核验 |
| 审核资料 | 无需登录、审核说明和用户提供的联系电话已保存并刷新核验；实际号码只填写到 Apple，不存入公开仓库或截图 |
| 发布方式 | Apple 门户已保存“手动发布此版本” |
| Archive | `app/build/ReleaseCandidate/Leanora-1.0-3-AppStore-Privacy-Signed.xcarchive`；修正旧版本隐私页文案后构建成功，当前为 Apple Development 签名 |
| 签名检查 | 获得系统信任服务访问后 `codesign --verify --deep --strict` 通过；初始受限检查的信任错误另行保留说明 |
| 权限 | HealthKit、background-delivery、Team 与应用标识匹配；最低 iOS18，iPhone |
| 发行导出 | 2026-10-22 重试仍失败：`No Accounts` / `No signing certificate "iOS Distribution" found`；Xcode 的 Apple Accounts 设置为空，当前没有可提交的发行 IPA |
| 构建上传 / 审核提交 | 未执行；不将 Archive 成功当作发行或提审成功 |

结构化结果见 [build audit](appstore-1.0-3-build-audit.json)，原始导出失败日志分别见 [首次](appstore-1.0-3-export-failure.log)、[最终归档重试](appstore-1.0-3-privacy-export-failure.log)。归档/开发缓存不提交到仓库。此前已上传的 0.2.0（2）仍为内部 TestFlight 构建，不能替代此次正式 App Store 候选。

本次上传记录见 [2026-10-22 状态](../../store/app-store-connect-upload-20261022.json)，实际页面见 [两套截图凭据](appstore-screenshots-uploaded-20261022.png)，新的发行导出错误见 [2026-10-22 日志](appstore-1.0-3-export-20261022-failure.log)。图片/文案上传成功不代表二进制上传、审核提交或公开上架成功。

## 当前外部状态

- Chrome 已登录 Manyao Li，正确 App 的 iOS 1.0 版本页、媒体管理和应用信息页均可编辑。截图上传使用系统文件选择器；未启用更广的扩展文件访问权限，未读取其他 App 的设置或提取认证令牌。
- 本次打开 Xcode 后，Apple Accounts 设置只有“Sign In…”按钮，账号列表为空。已请求用户登录。后续原生 UI 检查又返回 Mac 已锁定、自动解锁失败；需要用户手动解锁并完成 Xcode 登录。浏览器登录不等于 Xcode 账号可用，不直接假定必须重建证书。
- 用户确认已处理账号协议。素材编辑未遇到协议阻止；代理没有代为接受协议，也没有据此宣称所有商业/地区合规资料均已完成。
- 用户指定的 `https://leanora.ai/` 在 2026-10-22 的 HTTPS 复查仍返回 `SSL_ERROR_SYSCALL`。只记录当前客户端无法核验公开政策，不断言全球不可用。修复该网址或采用公开 GitHub 政策/联系页面的选择仍待确认，未擅自替换入口。

## 已准备的资料

中文/英文文案、两套各 7 张中文展示图、JSON 元数据和图标均通过本地检查，见 [素材包](../../store/README.md)。这两套截图和两种语言文案已经上传；截图只上传到简体中文，其他语言/设备使用 Apple 默认素材回退。版本说明已改为“首个版本”，首版表单未提供此字段，保留在本地。素材制作的真实页面及功能证据沿用此前报告；本次没有功能代码修改，未重跑全部 134 个功能方法。

[审核说明](../../store/review-notes.txt) 包含无需账号、可跳过健康权限、训练/饮食/身体/备份走查和真实数据边界，已保存并刷新核验。首次审核联系表单因缺电话被 Apple 拒绝，用户提供后补齐并成功保存。[提交草稿](../../store/submission-draft.json) 只记录电话已交给 Apple 的状态，号码字段在公开文件中仍为 null。价格、分发地区、支持 URL 未确认，不编造资料。

## 恢复后执行

1. 用户解锁 Mac，并在 Xcode 的 Apple Accounts 中登录 Manyao Li 所属 Apple 账号；Chrome 登录与素材上传已经恢复，无需重复上传现有 14 张截图。
2. 确认可公开访问且内容匹配的隐私政策、支持入口。如果 App 内 URL 需要变更，更新源码并以新本地路径重新 Archive；build 3 尚未上传，可继续作为本次候选。
3. 使用 `export_testflight_candidate.sh` 向一个尚不存在的目录重试发行导出；核验 Apple Distribution、Store 描述文件、`get-task-allow=false`、HealthKit 权限和图标。当前开发签名归档不能直接当作已分发 IPA。
4. 使用 [正式上传选项](../../config/ExportOptions-AppStore-Upload.plist)：`destination=upload`、`testFlightInternalTestingOnly=false`、`manageAppVersionAndBuildNumber=false`、`uploadSymbols=true`。先验证最终包和资料，再实际上传。
5. 已保存的截图、双语文案和审核联系方式保持；继续完成年龄分级/隐私/内容权利与必要地区声明，确认可用支持 URL、价格及地区。
6. 等 Apple 处理完成，选择 1.0（3），添加审核并点击实际的 Submit for Review；以门户最终状态核验提交。计划采用审核后手动发布，不把加入草稿当作已送审。

最低/当前系统物理 iPhone、锁屏/后台、多来源及时区、VoiceOver 与专业内容复核没有在本次构建中被补做，仍保留在 [发布清单](../release-checklist.md)，不能宣称已通过。
