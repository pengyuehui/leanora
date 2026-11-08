# Leanora 1.5（9）发行记录

2026-11-08：**已正式提交，Apple 显示「正在等待审核」和「已提交 1 个项目」**。本地在 20:34（Asia/Shanghai）记录可见结果；未将观察时间冒充 Apple 的精确提交时间。保留审核后手动发布，未执行公开上架。

- 审核单：`d7a78997-931a-4496-a378-e660acf1195c`；构建 `47198a61-b947-498f-8bfd-26b51562bec4`，1.5（9）。[正式回执](appstore-submission-20261108.json)、[等待审核画面](appstore-waiting-review-20261108.png)、[Apple 审核页面](https://appstoreconnect.apple.com/apps/6825234654/distribution/reviewsubmissions/details/d7a78997-931a-4496-a378-e660acf1195c)。旧 1.4 已可分发，本次未撤回或发布旧版。
- 功能源：`3d898e1`。152 项核心通过、2 项既有容量跳过，4 项原生 Health 单元和分批 10 个 UI 用例通过；见[功能验收](../history-actions-health-20261107/README.md)。本次没有把沿用结果描述为重新运行全套。
- 发行源：`fe88be6`，1.5（9）。不可变快照的 1905 个应用/工程输入 SHA-256 一致，见[源码凭据](release-source-proof-20261108.json)。原有三个工程/资源差异保留，仅提交版本号增量。
- 发行包：Xcode Organizer 标准 App Store Connect 上传成功，并 Export 同次分发。严格签名为 Apple Distribution: Manyao Li（8ZP3NMT2A8），get-task-allow=false，HealthKit 与后台交付权限保留。目录、1765 图片、3 个许可声明、Assets、隐私清单和无 Debug 测试标记审计通过。[审计](distribution-audit-20261108.json)、[上传记录](appstore-upload-20261108.json)、[Xcode 成功画面](xcode-upload-complete-20261108.png)。
- Apple 构建：服务器选择器列出 1.5（9），关联并保存后通过“添加以供审核”校验，随后正式提交成功。没有另外读取 TestFlight 的 VALIDATED 字段，不把它记作独立观察结果。
- 素材：截图用例 1 项通过，38.183 秒。7 张原生源图为 1206×2622；本地另生成中/大屏 14 张 RGB 展示图，保持源图比例与内容，页脚不覆盖 UI。[来源](store-screenshot-sources.json)、[素材校验](store-kit-validation-20261108.json)。门户实际关联 7 张必填中屏图；新页面重载后顺序 01–07、所有缩略图完整且 naturalWidth=331，见[门户凭据](appstore-assets-proof-20261108.json)和[页面截图](appstore-assets-20261108.png)。
- 选填大屏：旧版覆盖已移除。Mac 再次锁定后，按 Apple 页面“必填/选填”使用已完成的必填七图送审，未宣称大屏七图已上传；本地两套图仍可用。英文文案说明界面中文，采用主语言截图回退。
- 文案与网站：中英文介绍、推广文本、新版说明与审核备注逐字回显核对，见[门户元数据](appstore-metadata-proof-20261108.json)。隐私/支持 HTTPS 200 且为健身内容，见[网站检查](public-websites-20261108.json)。审核私人联系方式仅沿用 Apple 字段，没有写入仓库。

CLI No Accounts / 缺少本地发行私钥问题通过现有账号的 Organizer 流程解决，没有提取凭据或修改安全设置。截图系统选择器曾受锁定、浏览器连接和排序影响；恢复后确认仅七个正确文件再上传。媒体管理重排尺寸时，取消了一次针对中屏的误选替换弹窗，没有删除新上传的中屏图。

完整哈希与范围见[verification.json](verification.json)。不将等待审核等同审核批准，不声称真机 Health、最低 iOS 18、锁屏/后台及真实 VoiceOver 已验收。最终状态见[发行 JSON](../../../store/app-store-release-1.5-9-20261108.json)。
