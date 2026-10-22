# App Store 1.0（3）发行状态

更新：2026-10-22。用户切换 Manyao Li 账号后恢复工作。**含新版图标的 1.0（3）已正式上传，Apple 二进制状态为“已验证”，并已关联到 iOS 1.0 版本，重新加载后确认保存。尚未提交 App Review，也未公开发布。**

最新机器记录见 [发行回执](../../store/app-store-release-20261022.json)，签名与上传证据见 [发行包核验](appstore-1.0-3-distribution-audit-20261022.json)。[此前停止保存点](../../store/stop-point-20261022.json) 保留历史状态；其中签名失败和未上传的描述不代表当前进展。

| 项目 | 已核验结果 |
|---|---|
| 应用 | Leanora Fitness；Apple App ID `6825234654` |
| Bundle / Team | `ai.leanora.fitness` / Manyao Li，`8ZP3NMT2A8` |
| 版本 / 构建 | 1.0（3）；Apple 构建 ID `74e136c3-fa1c-4175-8d1d-ef47cd9e1f17` |
| 发行签名 | Apple Distribution；深度严格签名验证通过；Store profile 无设备列表，`get-task-allow=false` |
| 权限 | HealthKit、background-delivery、Team 与 Bundle 标识匹配；最低 iOS18，iPhone |
| 图标 | 本地发行包 Assets.car 与最终 Archive 一致；新版源图 SHA256 核对通过，Apple 门户页头已显示新版蓝色图标 |
| 正式上传 | 10:10:34 上传成功；`testFlightInternalTestingOnly=false`，请求上传 symbols，不自动改版本/构建号 |
| Apple 处理 | 门户显示二进制“已验证”，上传时间 10:11，包含符号“是”，非豁免加密“否” |
| 版本关联 | 已选择构建 3 / 1.0，保存后重新加载仍存在 |
| 商店截图 | 简体中文 1206×2622、1320×2868 各 7 张；此前刷新验证数量、顺序 |
| 文案 / 审核资料 | 中英文介绍、推广文本、关键词、副标题、分类、版权、无需登录、审核说明和联系资料已保存；实际审核电话只填写给 Apple |
| 年龄 / 医疗 / 版权 | 一般 13+（旧系统及部分地区 12+）、非受监管医疗设备声明已核验；USDA 第三方内容必要权利本次重新保存并刷新核验 |
| 首发价格 | 用户明确选择免费；重新进入“当前价格”表，175 个国家/地区全部 0.00 |
| 发行范围 | 174 个国家/地区在 App 发布时供应；中国大陆未供应，尚缺备案资料；未来新增地区自动供应已启用，仍受 Apple 当地要求约束 |
| 发布方式 | 审核后手动发布 |
| 隐私 | “不收集数据”答案草稿已保存；政策 URL 未完成有效性核验，尚未发布隐私答案 |

Apple “已验证”的 [页面凭据](appstore-1.0-3-validated-20261022.png)、[当前免费价格](appstore-free-prices-20261022.png)、[174 地区供应](appstore-availability-174-20261022.png) 均为实际门户页面；不包含审核电话、账号私密联系资料或认证信息。

实际点击“添加以供审核”后，Apple 拒绝加入审核，明确列出：隐私政策 URL、发布隐私处理信息，以及简体中文和英语（美国）的技术支持 URL。见 [Apple 必填项检查](appstore-review-blockers-20261022.png)。此次检查没有创建成功的审核提交；没有以占位 URL 绕过要求。

## 发行包与上传的边界

最终 Archive：`app/build/ReleaseCandidate/Leanora-1.0-3-AppStore-Privacy-Signed.xcarchive`。

验证的本地发行 IPA：`app/build/Exports/Leanora-1.0-3-AppStore-Holder-20261022/Leanora.ipa`，2,204,721 字节，SHA256 `a3da1559dcf609d91bae87d3e23132cf2b10ff7dd112447919de438134196936`。正式上传由 Xcode 从同一 Archive 重新导出；此摘要仅对应本地验证包，不冒充上传传输包的摘要。

原始完整分发日志仅保存在忽略的 `app/build/`，公开回执只保留成功状态行与日志摘要。旧 0.2.0（2）仍是旧图标的内部 TestFlight 构建；它不是本次正式候选。

## leanora.ai 仍需恢复

用户选择“修复 leanora.ai 后使用原网址”。保留政策入口 `https://leanora.ai/`，拟使用支持入口 `https://leanora.ai/support/`，未切换到 GitHub 备用网址。

本次检查旧公共解析地址的 HTTPS 握手失败，HTTP 跳转腾讯云备案拦截页。用户打开的 GoDaddy 页面已显示新 A 记录，但公共/权威查询仍返回旧地址；以域名 SNI 直连新地址时，证书验证通过，站点响应 500。需要主机后台检查网站服务，不能把 DNS 编辑或有效证书当作页面已经恢复。代理没有更改 DNS、网站服务或安全设置。

[待部署静态页面](../../website/README.md) 已从政策源文件和新增支持文档生成，本机浏览器核验了标题、正文、导航和邮箱入口；本机预览不代表公开部署。主机修复后须通过正常公共解析访问两个 HTTPS URL，核验有效证书、200 与正确正文，再保存商店 URL、发布隐私答案。

## 尚待完成

1. 取得已登录的主机后台并检查现有网站及错误日志；修复 500，确认 DNS 传播，发布并公开验证政策和支持页面。
2. 保存政策/支持 URL，发布经核对的“不收集数据”隐私答案；不将本机 Health 访问误填为开发者服务器收集。
3. 完成或明确解决 [发布清单](../release-checklist.md) 中尚未验收的真机、锁屏/后台、多来源/时区、VoiceOver 和专业内容复核。
4. 最终提交 App Review，并以 Apple 实际“等待审核”等状态记录结果；当前“准备提交”不是送审成功。

本次无 App 功能源码改动，未重跑此前 134 个功能方法；原报告的真机及专业内容验收缺口仍保留，不能据 Apple 二进制验证宣称功能验收完成。未代为接受新的法律协议，未提取浏览器或 Xcode 认证信息。
