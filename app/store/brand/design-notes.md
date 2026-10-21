# Leanora 图标与商店视觉

2026-10-21。蓝白配色延续原生 App 的操作强调色；以大字号中文和真实页面作为主要内容，突出日常记录。

新版图标使用满版钴蓝底，白色 L 表达日记的稳定基线，独立上扬笔画表达持续记录的方向。取消旧图标的内嵌圆角色块与外围浅色边，让系统图标蒙版统一处理外轮廓。32 px 时仍可辨识两个笔画；不使用器械、餐具或 Apple Health 标志。

`icon-master.png` 为内置 imagegen 生成的 1254×1254 RGB 原图，未从其他 App 取材。`app-icon-1024.png` 为等比例导出的 1024×1024 RGB PNG，无 alpha。导出脚本 `app/scripts/GenerateBrandAssets.swift` 使用 CoreGraphics/ImageIO，保留母图，不裁切、不添加圆角。

生成提示词：

> Use case: logo-brand. Design ONE final iOS app icon for Leanora Fitness, a calm, precise training and nutrition journal. Square 1024 x 1024 artwork, full bleed opaque saturated cobalt blue background (#2155D6), no inset rounded square, no outer white margins, no pre-rounded corners because iOS applies its own mask. A single memorable white monogram in the center: an elegantly rounded L whose upright and bottom stroke form a strong stable base, with a separate rising diagonal stroke in the upper right like a forward training tick. Optical balance, generous internal negative space, substantial rounded stroke weight, exceptionally simple silhouette legible at 32 pixels. The L and rising stroke should feel purposefully related, like recording and steady progress, without resembling a stock chart or lightning bolt. Crisp flat vector-style finish, white against cobalt; extremely subtle tonal depth on the blue is acceptable. No lettering, no wordmark, no microdetails, no human figure, no dumbbell, no fork, no heart, no Apple/Health logo, no mockup, no shadow outside the square, no 3D glass bevel, no decorative border. Output the icon artwork itself, exactly one icon.

截图只对真实 App 截图作完整等比例排版，未重画页面、改写数据、拼接不存在的功能或模拟健康授权成功。所有可见业务数字来自隔离测试库中的示例记录，不是用户健康数据，不代表效果承诺。截图中的热量目标只是演示输入，并非饮食建议。

源图来自 iOS 27.1 / iPhone Duo 外屏；当前本机运行时只支持该设备，创建 iPhone 18 Pro 返回 incompatible device。商店展示图按 Apple 列出的中/大屏尺寸另行排版，并保持源图宽高比；它们不是这些机型的原生满屏截图。发布前应在目标机型补充原生验收，不能据此声明机型优化。
