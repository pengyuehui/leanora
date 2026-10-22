# leanora.ai 双产品网站

新版以 Leanora 品牌首页承接两款产品，围棋复盘与训练饮食各有独立详情页，支持与隐私按产品分流。采用暖白背景、中文宋体标题和真实产品截图；围棋使用绿色，健身使用蓝色。桌面并列展示产品，手机提供两个直接入口。

**部署状态：2026-10-22 新版仅在本地完成构建、视觉和交互验证，尚未替换线上网站。** 此前线上已有效的健身政策与支持网址继续保留。不要将本地通过理解为已上线。

## 页面结构

| 路径 | 内容 |
| --- | --- |
| `/` | 品牌首页与两个产品入口 |
| `/go/` | Leanora AI 围棋复盘与练习 |
| `/fitness/` | Leanora Fitness 训练与饮食日记 |
| `/support/` | 双产品支持中心 |
| `/go/support/` | 围棋常见问题和联系入口 |
| `/policies/` | 按产品区分的隐私中心 |
| `/privacy/` | 既有围棋隐私政策，正文保留 |
| `/fitness/privacy/` | 既有健身隐私政策，正文保留 |
| `/fitness/support/` | 既有健身支持说明，正文保留 |

原首页的 `/#review`、`/#training`、`/#parents` 会跳转至围棋详情页对应位置。App Store Connect 使用的健身支持与隐私地址无需修改。

## 编辑与生成

在仓库根目录运行：

```sh
PYTHONDONTWRITEBYTECODE=1 python3 app/scripts/build_public_site.py
PYTHONDONTWRITEBYTECODE=1 python3 app/scripts/validate_public_site.py
node --check app/website-src/assets/site.js
```

- 公共模板、产品文案、样式和交互：`app/website-src/`。
- 健身政策和支持正文：`app/docs/privacy-policy.md`、`app/docs/support.md`。
- 原围棋政策正文：`app/website-src/pages/go-privacy.html`，来自既有公开页面。
- 健身截图与图标：沿用 `app/store/` 中已准备的公开素材。
- 生成结果：`app/website/`；应修改源文件后重新生成。
- 可上传压缩包：`app/build/leanora-dual-product-website.zip`，约 5 MB。
- `manifest.json` 列明九个页面和每个公开文件的大小及 SHA-256。

本网站无需安装依赖或服务器端程序，不含追踪脚本、外部字体、第三方资源、表单或 Cookie。截图放大、手机导航、问答展开均可键盘操作；减少动态效果的系统偏好会被尊重。没有 JavaScript 时，主要内容与普通链接仍可使用。

## 通过 SCP 部署

1. 确认服务器上 `leanora.ai` 对应的网站根目录，先保留当前站点的完整可恢复副本。
2. 将压缩包传至服务器临时目录，再解压至暂存目录。包内直接是 `index.html`、`go/`、`fitness/`、`support/`、`policies/`、`privacy/`、`site-assets/` 和 `manifest.json`。
3. 将这些文件按原有目录结构复制到网站根目录。此次会更新根首页与三个既有政策/支持页面，增加产品详情等页面。不要把压缩包的外层目录作为新的站点根目录。
4. 保留服务器配置、域名验证文件及其他无关文件；不要清空网站目录，也不要采用删除目标端其他文件的同步选项。无需上传整个 Git 仓库、README、应用二进制或构建日志。
5. 主机应以 UTF-8 返回页面，将目录路径映射到其中的 `index.html`，优先匹配实际文件，再处理既有 SPA 回退。保持 HTTPS 证书和 HTTP 到 HTTPS 的跳转；如果启用了缓存，刷新首页与 `site-assets/` 缓存。

上传后从正常公共网络检查：首页能进入两个产品；手机没有横向滚动；支持和隐私链接对应正确产品；九个页面均返回正确正文；截图放大可关闭；`/privacy/`、`/fitness/privacy/`、`/fitness/support/` 的 HTTPS 有效。若需要回滚，恢复第一步的站点副本。

## 已完成验证

本地九页在 1280 × 720 和 390 × 844 下均无横向溢出；导航、截图放大与焦点恢复、问答展开、旧首页锚点兼容通过。静态验证覆盖 232 个站内引用、三个既有正文、压缩包文件与哈希。记录与截图见 [验证报告](../docs/qa/website-redesign/README.md)。
