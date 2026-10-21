# Leanora App Store 素材包

2026-10-21；名称 **Leanora Fitness**，Bundle ID `ai.leanora.fitness`，Apple App ID `6825234654`。本包是本地可审查交付物，尚未上传图片/文案或提交审核。

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

英文文案已准备；当前截图仅本地化为简体中文，不把中文截图标作英文截图。

## 截图顺序与真实性

1. 每日概览：训练与饮食一处记录。
2. 我的计划：自己的动作、组数与每周安排。
3. 逐组训练：实际负重、次数、完成与暂停。
4. 饮食日记：当日热量与三大营养素。
5. 食物与份量：来源、数量与餐次。
6. 身体与趋势：回看训练容量及历史记录。
7. Apple Health：用户选择范围与方向。

截图测试在隔离 UI 测试库中创建示例业务记录，采用真实存储、目录、计算和界面；未植入或伪造 Health 样本、授权成功、同步成功状态。每张源图完整等比例排入展示图，未重画 UI、改数字或拉伸页面。App 原图来自当前本机唯一支持的 iPhone Duo 外屏；中/大屏展示图是营销排版，并非这些机型的原生满屏截图，不能替代对应设备验收。

已对照 [Apple 截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) 核对导出尺寸、PNG 格式及无透明要求。文案按 [Apple 平台版本信息](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/) 检查：推广文本≤170 字符、描述≤4000 字符、关键词≤100 UTF-8 字节；副标题≤30 字符。

## 验证与历史

- 截图流程 `StoreScreenshotTests/testCaptureChineseStoreScreenshots()` 1 项通过，输出 7 张原始截图。它是素材制作流程，不重复计入原 134 项功能覆盖，也未重跑全部功能测试。
- 首轮在初始化画面超时；将截图模式完成引导的时机移到全部服务准备好之后，后续进入主页面。第二轮在 Duo 上按 NavigationBar 查找返回按钮失败；改为实际“开始训练”入口继续。最终完整流程通过，原始失败/重试日志保留在 `app/build/store-screenshots*.log`；被中断的系统诊断收集不算成功。
- 原 AppKit 位图导出器在当前系统崩溃，已改为 CoreGraphics/ImageIO；导出及资产编译通过。排版器依据真实中文字体行高检查可见字符，发现并修复标题容器过短。
- 桌面浏览器检查布局、图片与入口；实际点击复制副标题后显示“已复制副标题”。页面尊重减少动态效果，移动布局通过 CSS 断点回落；未把此项声明为真机浏览器全量验收。
- 新图标接入源码后，本机未签名 Release Archive 成功，检查未发现截图启动参数、示例模板或夹具函数标记。该新 Archive 未上传；已经上传的 0.2.0（2）二进制仍使用旧图标。新版图标需要在下一次签名构建递增 build 后上传。

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

需确认品牌、公开隐私政策的可访问性及实际内容、支持页面正式 URL、真机验收及 Apple 所需审核信息。`metadata.json` 将未部署的支持 URL 保持为空，并单独列出建议地址，不把占位地址当作已上线页面。导出尺寸与字段长度通过不代表 Apple 审核通过。
