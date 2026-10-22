# leanora.ai 公开页面

这是健身产品的静态页面。**2026-10-22 用户通过 SCP 部署后，已公开核验两页有效 HTTPS、200，并与本地生成 HTML 逐字节一致。** 采用 `https://leanora.ai/fitness/privacy/` 和 `https://leanora.ai/fitness/support/`，与既有围棋网站共用域名但使用独立路径。不含追踪脚本、外部字体、表单或服务器依赖。

从仓库根目录运行 `PYTHONDONTWRITEBYTECODE=1 python3 app/scripts/build_public_site.py`，由 `app/docs/privacy-policy.md` 和 `app/docs/support.md` 生成 `fitness/privacy/index.html`、`fitness/support/index.html`。请修改 Markdown 源文件后重新生成。

部署前先检查当前主机的网站目录、既有应用、反向代理和错误日志，保存可恢复副本。只新增两个 `fitness/` 路径的 HTML 文件，不覆盖站点根目录或围棋的 `/privacy/`；不把仓库、构建日志、README 或审核联系方式作为网站目录上传。

主机应以 UTF-8 返回两个页面，`/fitness/privacy/` 和 `/fitness/support/` 分别映射到各自的 `index.html`，先匹配这些文件再采用现有站点的 SPA 首页回退。证书覆盖 leanora.ai，HTTP 跳转 HTTPS。保留原有邮件、域名验证与其他无关 DNS 记录。

历史检查曾见 TLS 失败、500，以及域名恢复后围棋内容与健身用途不匹配。用户随后 SCP 上传了两条独立健身路径；公开网页的正文、主体、邮箱和导航已核验，详见 [网站核验](../docs/qa/fitness-website-check-20261022.json)。代理没有修改 DNS 或网站服务。

部署后必须从正常公共解析访问两个 HTTPS URL，确认 200、正确页面正文、邮箱和运营主体、导航及移动阅读，再写入 App Store Connect 并发布隐私答案。仅直连新 IP、忽略证书、首页返回一个错误页或本地预览通过均不算恢复成功。
