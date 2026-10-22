# leanora.ai 公开页面

这是待部署的静态文件，**文件存在不代表网站已经恢复**。保持用户指定的政策入口 `https://leanora.ai/`，支持入口拟为 `https://leanora.ai/support/`。不含追踪脚本、外部字体、表单或服务器依赖。

从仓库根目录运行 `PYTHONDONTWRITEBYTECODE=1 python3 app/scripts/build_public_site.py`，由 `app/docs/privacy-policy.md` 和 `app/docs/support.md` 生成 `index.html`、`support/index.html`。请修改 Markdown 源文件后重新生成。

部署前先检查当前主机的网站目录、既有应用、反向代理和错误日志，保存可恢复副本；不要直接覆盖未知的现有站点。只发布两个生成的 HTML 文件，不把仓库、构建日志、README 或审核联系方式作为网站目录上传。

主机应以 UTF-8 返回两个页面，`/support/` 映射到 `support/index.html`，有效证书覆盖 leanora.ai，HTTP 跳转 HTTPS。保留原有邮件、域名验证与其他无关 DNS 记录。

2026-10-22 检查：GoDaddy 页面显示新的 A 记录，公共/权威查询仍返回旧地址；旧地址 HTTPS 握手失败，HTTP 进入腾讯云备案拦截页。直接以 leanora.ai 的 SNI 和证书验证连接新地址，证书校验通过，但返回 HTTP 500。尚未取得主机后台，未修改 DNS 或网站服务。

部署后必须从正常公共解析访问两个 HTTPS URL，确认 200、正确页面正文、邮箱和运营主体、导航及移动阅读，再写入 App Store Connect 并发布隐私答案。仅直连新 IP、忽略证书、首页返回一个错误页或本地预览通过均不算恢复成功。
