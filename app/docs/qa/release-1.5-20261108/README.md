# Leanora 1.5（9）发行记录

2026-11-08：当前为送审准备状态，不表示已上传或进入审核。用户已明确要求提交 App Store。Apple 1.4 当日已显示可分发，1.5 独立草稿已创建，原有审核后手动发布选择保留。

- 功能源：提交 `3d898e1`，152 项核心通过、2 项既有容量跳过，4 项原生 Health 单元及分批 10 项 UI 用例通过；边界见[功能验收](../history-actions-health-20261107/README.md)。
- 发行源：提交 `fe88be6`，版本 1.5（9）。从 Git 生成不可变快照，1905 个应用/工程文件的 SHA-256 一致，见[源码凭据](release-source-proof-20261108.json)。原有工程、Info.plist 与字符串未提交改动保持，工程只提交版本号增量。
- 原生素材：新版七页截图用例 1 项通过，38.183 秒。源图 1206×2622，另排版为 1206×2622 和 1320×2868，完整保留源 UI 的比例与内容，避免页脚覆盖画面。14 张导出均为 RGB、不透明，App 图标 1024×1024。见[来源](store-screenshot-sources.json)和[素材校验](store-kit-validation-20261108.json)。中文界面截图用于简体中文；英文文案明确说明界面中文，不将源图冒充英文界面。
- 元数据：中英文介绍、推广文本、新版说明和审核备注已保存并重新进入语言核对，见[门户回显](appstore-metadata-proof-20261108.json)。审核联系方式沿用 Apple 已保存字段，没有写入公开仓库。
- 网站：隐私政策和支持页 HTTPS 200，含健身产品内容，见[检查](public-websites-20261108.json)。
- Archive：Release 签名 Archive 成功，严格签名验证通过，HealthKit 与后台交付 entitlement 存在，Debug 截图/测试标记不在 Release 二进制。Archive 是开发签名，尚不等于 App Store 发行导出。
- 导出：标准 CLI 返回 No Accounts / 缺少本地 Distribution 私钥；Xcode 界面能看到 Manyao Li 团队。下一步使用 Organizer 标准分发及同次导出审计，不提取账号凭据或私钥。

当前阻塞：Mac 锁定，用户解锁请求已发送。Chrome 扩展没有本地文件访问，回退系统文件选择器；不修改扩展授权。素材已各放在仅含 7 张图的暂存目录，避免带入旧版图片。门户的旧中屏关联已从 1.5 草稿移除，素材仍保留在 Apple 素材库，后续需完成两套新版上传并重载核对。

当前进度见[发行 JSON](../../../store/app-store-release-1.5-9-20261108.json)。未声称物理 iPhone Health、最低 iOS 18、锁屏/后台投递、真实 VoiceOver、Apple 处理成功或正式审核已完成。
