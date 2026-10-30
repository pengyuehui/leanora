# Leanora App Store 素材包

更新：2026-10-30；名称 **Leanora Fitness**，Bundle ID `ai.leanora.fitness`，Apple App ID `6825234654`。本目录现为 **1.3（7）素材源**：7 张真实页面、两套展示尺寸，新增组合餐展示，并更新双语介绍、版本说明和审核指引。签名及本地发行导出已完成，1.3（7）上传成功且 Apple 二进制已验证；正式送审状态以 [1.3 发行记录](app-store-release-1.3-7-20261030.json) 为准。本地素材预览不代表已发布。

上一版 1.2（6）于 2026-10-30 09:08 进入等待审核；Apple 当前要求移除该版本才能送审新构建。1.1 已可分发。历史回执保留，免费、既有销售范围和审核通过后手动发布的设置沿用。

## 交付内容

| 内容 | 位置 |
|---|---|
| 可交互预览：查看大图、下载图片、复制中文文案 | [index.html](index.html) |
| 7 张截图总览 | [contact-sheet.png](contact-sheet.png) |
| 新版图标，1024×1024、RGB、无透明 | [brand/app-icon-1024.png](brand/app-icon-1024.png) |
| imagegen 原图、设计思路与完整提示词 | [brand/design-notes.md](brand/design-notes.md) |
| 中文商店展示图：中屏，1206×2622 | [zh-Hans/iphone-medium](zh-Hans/iphone-medium) |
| 中文商店展示图：大屏，1320×2868 | [zh-Hans/iphone-large](zh-Hans/iphone-large) |
| 原始 App 截图，1398×2034 | [zh-Hans/source](zh-Hans/source) |
| 中英文副标题、推广文本、说明、关键词、版本说明 | [metadata.json](metadata.json)、[zh-Hans](zh-Hans)、[en-US](en-US) |
| 产品定位、一句话介绍、简短介绍与分享文案 | [product-introduction.md](product-introduction.md) |
| 截图流程结果 / 资产与 Release 检查 | [screenshot-test-summary.json](screenshot-test-summary.json)、[verification.json](verification.json) |
| 桌面浏览器实际预览截图 | [preview-desktop.png](preview-desktop.png) |

本地包含简体中文和英语（美国）文案。1.3 的门户保存状态见发行记录；截图用于简体中文，英语采用主语言素材回退，不把中文截图另标为英语截图。

## 截图顺序与真实性

1. 每日概览：训练与饮食一处记录。
2. 常用组合餐：按本次份数预览，再记入独立饮食明细。
3. 逐组训练：实际负重、次数、完成与暂停。
4. 饮食日记：当日热量与三大营养素。
5. 食物与份量：来源、数量与餐次。
6. 身体与趋势：回看训练容量及历史记录。
7. Apple Health：用户选择范围与方向。

截图测试在隔离 UI 测试库中创建示例业务记录，采用真实存储、目录、计算和界面；未植入或伪造 Health 样本、授权成功、同步成功状态。每张源图完整等比例排入展示图，未重画 UI、改数字或拉伸页面。App 原图来自当前本机唯一支持的 iPhone Duo 外屏；中/大屏展示图是营销排版，并非这些机型的原生满屏截图，不能替代对应设备验收。

已对照 [Apple 截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) 核对导出尺寸、PNG 格式及无透明要求。文案按 [Apple 平台版本信息](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/) 检查：推广文本≤170 字符、描述≤4000 字符、关键词≤100 UTF-8 字节；副标题≤30 字符。

## 当前验证

本轮源截图来自通过的截图制作用例，以及通过的组合餐半份流程；完整来源、原图哈希和原始失败批次口径见 [截图来源](screenshot-test-summary.json)。14 张展示图均为 RGB、无透明，尺寸及源图哈希已检查，双语字段符合 Apple 长度限制。网页预览图片已实际加载并查看，完整功能结果见 [1.3 QA](../docs/qa/nutrition-workflow-1.3/verification.json)。

## 早期素材工具与发布历史

- 截图流程 `StoreScreenshotTests/testCaptureChineseStoreScreenshots()` 1 项通过，输出 7 张原始截图。它是素材制作流程，不重复计入原 134 项功能覆盖，也未重跑全部功能测试。
- 首轮在初始化画面超时；将截图模式完成引导的时机移到全部服务准备好之后，后续进入主页面。第二轮在 Duo 上按 NavigationBar 查找返回按钮失败；改为实际“开始训练”入口继续。最终完整流程通过，原始失败/重试日志保留在 `app/build/store-screenshots*.log`；被中断的系统诊断收集不算成功。
- 原 AppKit 位图导出器在当前系统崩溃，已改为 CoreGraphics/ImageIO；导出及资产编译通过。排版器依据真实中文字体行高检查可见字符，发现并修复标题容器过短。
- 桌面浏览器检查布局、图片与入口；实际点击复制副标题后显示“已复制副标题”。页面尊重减少动态效果，移动布局通过 CSS 断点回落；未把此项声明为真机浏览器全量验收。
- 新图标接入源码后，本机 Release Archive 成功，检查未发现截图启动参数、示例模板或夹具函数标记。早期受邀 Admin 的发行导出失败已保留历史；用户切换 Manyao Li 账号后，1.0（3）发行签名核验与正式上传成功，Apple 显示二进制已验证、包含符号，门户页头也显示新版图标。旧 0.2.0（2）仍使用原图标。
- 2026-10-22 通过 Chrome 系统文件选择器上传两套截图，媒体管理页均显示 7/10，重新加载后数量、顺序保持。两种语言的介绍、推广文本和关键词回显均与本地源逐字一致，副标题与健康健美分类也在重新进入页面后确认。

## 复现

在仓库根目录执行。所有编译产物置于被忽略的 `app/build/`。

```sh
mkdir -p app/build
swiftc app/scripts/GenerateBrandAssets.swift -o app/build/GenerateBrandAssets
app/build/GenerateBrandAssets app/ios/Leanora/Resources/Assets.xcassets/AppIcon.appiconset
cp app/ios/Leanora/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png app/store/brand/app-icon-1024.png
swiftc app/scripts/RenderStoreScreenshots.swift -o app/build/RenderStoreScreenshots
app/build/RenderStoreScreenshots app/store
PYTHONDONTWRITEBYTECODE=1 python3 app/scripts/build_store_preview.py
PYTHONDONTWRITEBYTECODE=1 python3 app/scripts/validate_store_kit.py
python3 -m http.server 8794 --bind 127.0.0.1 --directory app
```

访问 `http://127.0.0.1:8794/store/index.html`。截图流程使用 Xcode Scheme `Leanora`，只运行 `LeanoraUITests/StoreScreenshotTests`，设备为兼容 iOS 27.1 的 iPhone Duo，语言 `zh-Hans`。从 `.xcresult` 导出附件后，按 `screenshots.json` 的 source 名称保存原图，之后重跑排版器。不要在用户资料库启动截图夹具；它只在 Debug、`--uitesting` 和截图参数同时存在时创建示例。

## 提交到商店前

政策和支持页面现已公开验收，中英文 URL 与描述均已保存到 Apple；`metadata.json` 的支持 URL 已改为核验后的正式地址。导出尺寸、字段长度与 Apple 二进制验证不等于审核通过，既有真机/专业内容验收仍按发布清单记录。

原域名恢复后属于围棋产品，健身 App 因此使用独立 `/fitness/privacy/` 和 `/fitness/support/`。用户 SCP 部署后，两页 HTTPS 200 且与交付 HTML 完全一致；App、源政策、双语介绍和 Apple 表单网址已同步。见 [网站部署说明](../website/README.md)、[公开网站核验](../docs/qa/fitness-website-check-20261022.json) 和 [构建 4 回执](app-store-release-1.0-4-20261022.json)。
