# App Store 1.0（3）提交准备

更新：2026-10-22。**用户随后要求“先保存现有工作后停止”；当前已停止，只有用户明确要求后才恢复。** 用户已明确要求“构建并提交 App Store”，并确认协议已处理、要求上传新图标和素材。**14 张中文截图、中英文商店文案与审核资料已保存到 Apple；新版图标所在的发行构建仍未上传，尚未提交 App Review。**

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
| 发行导出 | 用户完成登录后识别到受邀 Admin，但个人开发者团队不提供其证书资源权限；新重试报 `No Account for Team 8ZP3NMT2A8` / 无发行证书，仍没有发行 IPA |
| 构建上传 / 审核提交 | 未执行；不将 Archive 成功当作发行或提审成功 |

结构化结果见 [build audit](appstore-1.0-3-build-audit.json)，原始导出失败日志分别见 [首次](appstore-1.0-3-export-failure.log)、[最终归档重试](appstore-1.0-3-privacy-export-failure.log)。归档/开发缓存不提交到仓库。此前已上传的 0.2.0（2）仍为内部 TestFlight 构建，不能替代此次正式 App Store 候选。

本次上传记录见 [2026-10-22 状态](../../store/app-store-connect-upload-20261022.json)，实际页面见 [两套截图凭据](appstore-screenshots-uploaded-20261022.png)，新的发行导出错误见 [2026-10-22 日志](appstore-1.0-3-export-20261022-failure.log)。图片/文案上传成功不代表二进制上传、审核提交或公开上架成功。

## 当前外部状态

- Chrome 已登录 Manyao Li，正确 App 的 iOS 1.0 版本页、媒体管理和应用信息页均可编辑。截图上传使用系统文件选择器；未启用更广的扩展文件访问权限，未读取其他 App 的设置或提取认证令牌。
- 账号登录已成功，Xcode 显示受邀 Admin；团队详情的 Certificates, Identifiers & Profiles 为红色不可用。官方账户页核实注册身份为个人，协议接受日期为 2026-10-21。依据 [Apple 角色说明](https://developer.apple.com/help/account/access/roles)，个人会员邀请的用户只能管理 App Store Connect，不具备该会员的开发者签名资源访问权。已打开新增账号窗口，请求添加 Manyao Li 的 Account Holder 账号；未改权限、创建/撤销证书或保存任何密码/验证码。
- 用户确认已处理账号协议。素材编辑未遇到协议阻止；代理没有代为接受协议，也没有据此宣称所有商业/地区合规资料均已完成。
- 用户指定的 `https://leanora.ai/` 在 2026-10-22 的 HTTPS 复查仍返回 `SSL_ERROR_SYSCALL`。只记录当前客户端无法核验公开政策，不断言全球不可用。修复该网址或采用公开 GitHub 政策/联系页面的选择仍待确认，未擅自替换入口。

## 已准备的资料

中文/英文文案、两套各 7 张中文展示图、JSON 元数据和图标均通过本地检查，见 [素材包](../../store/README.md)。这两套截图和两种语言文案已经上传；截图只上传到简体中文，其他语言/设备使用 Apple 默认素材回退。版本说明已改为“首个版本”，首版表单未提供此字段，保留在本地。素材制作的真实页面及功能证据沿用此前报告；本次没有功能代码修改，未重跑全部 134 个功能方法。

[审核说明](../../store/review-notes.txt) 包含无需账号、可跳过健康权限、训练/饮食/身体/备份走查和真实数据边界，已保存并刷新核验。首次审核联系表单因缺电话被 Apple 拒绝，用户提供后补齐并成功保存。[提交草稿](../../store/submission-draft.json) 只记录电话已交给 Apple 的状态，号码字段在公开文件中仍为 null。价格、分发地区、支持 URL 未确认，不编造资料。

## 恢复后执行

1. 等用户明确要求恢复后，核对 Xcode 中 Manyao Li 的 Account Holder 账号与证书访问权限；受邀 Admin 的登录不能替代。Chrome 与素材上传已恢复，无需重复上传现有 14 张截图。
2. 确认可公开访问且内容匹配的隐私政策、支持入口。如果 App 内 URL 需要变更，更新源码并以新本地路径重新 Archive；build 3 尚未上传，可继续作为本次候选。
3. 使用 `export_testflight_candidate.sh` 向一个尚不存在的目录重试发行导出；核验 Apple Distribution、Store 描述文件、`get-task-allow=false`、HealthKit 权限和图标。当前开发签名归档不能直接当作已分发 IPA。
4. 使用 [正式上传选项](../../config/ExportOptions-AppStore-Upload.plist)：`destination=upload`、`testFlightInternalTestingOnly=false`、`manageAppVersionAndBuildNumber=false`、`uploadSymbols=true`。先验证最终包和资料，再实际上传。
5. 已保存的截图、双语文案、审核联系和年龄分级保持；核验版权声明最后一次保存结果，解决政策/支持 URL 并发布经过核对的隐私答案，确认价格及地区。
6. 等 Apple 处理完成，选择 1.0（3），添加审核并点击实际的 Submit for Review；以门户最终状态核验提交。计划采用审核后手动发布，不把加入草稿当作已送审。

最低/当前系统物理 iPhone、锁屏/后台、多来源及时区、VoiceOver 与专业内容复核没有在本次构建中被补做，仍保留在 [发布清单](../release-checklist.md)，不能宣称已通过。

## 用户要求停止时的保存点

见 [结构化保存点](../../store/stop-point-20261022.json)。签名重试日志见 [Admin 导出失败](appstore-1.0-3-admin-export-20261022-failure.log)，权限界面见 [Xcode 实际状态](xcode-signing-access-unavailable-20261022.png)。

- 年龄问卷已保存并重新进入页面核验：一般分级 13+，旧系统及部分地区为 12+；无覆盖分级。由于食品目录含啤酒/葡萄酒，如实申报偶尔提及酒精；健康主题为是，医疗治疗信息为无。
- 已声明非受监管医疗设备，重新进入页面后显示该声明。
- 内容版权选择了有必要权利的第三方内容（USDA CC0 数据）；点击全页保存后显示对应文案，最终重新加载后的核验尚未完成，用户此时要求停止。恢复时先检查，不直接宣称已经持久化。
- 隐私问卷“不收集数据”已保存并刷新核验，尚未点击发布；门户政策 URL 仍为空，可访问的公开政策/支持入口仍待解决。见 [隐私草稿截图](appstore-privacy-draft-20261022.png)。
- TestFlight 仅看到原 0.2.0（2）内部构建，状态已为“准备测试”。1.0（3）仍未上传、未提审，新图标仍未上传。
- 停止后不再继续发行、上传或门户编辑。实际审核电话、账号持有人邮箱/电话/地址和认证信息不进入公开仓库。
