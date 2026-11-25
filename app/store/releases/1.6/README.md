# 1.6 本地发布素材

该目录是 1.6（10）的本地候选资料，不表示已经上传、送审或发布。

- `zh-Hans/source/`：七张未经修改的 iOS 原生截图，来自通过的 `StoreScreenshotTests` 隔离夹具；不含用户实际健康数据。
- `zh-Hans/iphone-medium/`：7 张 1206 × 2622 展示图。
- `zh-Hans/iphone-large/`：7 张 1320 × 2868 展示图。
- `contact-sheet.png`：七页预览。
- `screenshots.json`：标题与页面映射；`sources.json`、`rendered.json` 为来源及哈希。
- `zh-Hans/whats-new.txt`、`en-US/whats-new.txt`：本版更新说明。

展示图使用原图标和现有 `app/scripts/RenderStoreScreenshots.swift`，围绕真实截图排版，未修改截图内的产品状态。渲染工作目录为忽略的 `app/build/v16-store-materials`，含同一组源截图、索引和原图标。主目录仍保留上一版资料，没有自动替换线上文案。

发行账号与真机状态见 [QA](../../../docs/qa/training-recording-1.6-20261126/README.md)。
