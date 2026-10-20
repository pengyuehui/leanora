# 阶段 1 实现与验证记录

更新：2026-10-20。范围：主开发计划 U1。编码与模拟器验证完成：最终 **19 项通过、0 失败、0 跳过、0 运行时告警**，iPhone Release 构建通过。原计划的真机验收仍待连接设备并选择开发团队。

## 交付物

- 原生 SwiftUI iPhone 工程、原创图形与暖白/深绿主题、深色模式。
- 三步首次使用；可不设置目标、跳过健康访问，重开后不重复引导。
- 今天 / 训练 / 饮食 / 趋势 / 我的五个 Tab，各自独立导航。
- 单位与可选目标的校验、保存、重新编辑、清除；数字键盘有单一“完成”入口。
- 真实 HealthKit 授权入口、读写范围选择、不可用和错误路径；不推断读取权限，不把请求完成表示为已同步。
- 真实通知授权、拒绝/错误处理、系统返回时刷新；当前不调度提醒。
- 隐私说明、配置损坏提示、中文字符串目录、权限说明和隐私清单。
- 产品范围、交互流程、依赖和内容来源清单。

训练、饮食记录与健康样本同步按 U2–U7 实现，不属于 U1。当前空状态不包含虚构记录。

## 环境与结果

| 检查 | 结果与证据 |
|---|---|
| 编译环境 | Xcode 27.1（27A9275），Swift 6.4，最低部署 iOS 18.0 |
| iPhone Release 构建 | 通过；`app/build/release-build.log`。未签名，只证明编译，不是可分发安装包 |
| Release 测试入口检查 | 二进制不包含 `--uitesting`、权限模拟器类名或系统权限测试标记；支持平台为 iPhoneOS |
| 配置验证 | Info.plist、HealthKit entitlements、PrivacyInfo.xcprivacy 与工程格式检查通过；工程生成脚本 Ruby 语法检查通过 |
| Swift Package 基础服务测试 | 9 项通过、0 失败；同一份生产代码，见 `app/build/unit-tests-run.log` |
| iOS 模拟器基础服务测试 | 9 项通过；真实 UserDefaults 保存/重建实例、HealthKit 类型映射，系统授权边界使用适配器测试 |
| iOS UI 测试 | 10 项通过：8 个页面场景和 2 个真实系统权限场景。与 9 项单元测试在同一轮完整通过，结果为 `app/build/U1Verified.xcresult` 与 `app/build/u1-verified.log` |
| 模拟器 | iPhone Duo / iOS 27.1（24A94425）；此 Runtime 仅支持该机型，不能据此宣称覆盖普通小屏 iPhone 或最低 iOS 18 的实际运行 |
| Mac Catalyst 补充检查 | 临时工程编译、启动并走通首次使用、五个页面、单位与目标编辑；不作为 iPhone 验收的替代 |
| 真机、VoiceOver、签名安装 | 未执行：没有连接物理 iPhone，工程未选择 Developer Team。本机能枚举开发身份，本轮只使用模拟器本地签名 |

## 自动化场景

基础服务 9 项：偏好重建保留、输入错误不覆盖原值、损坏配置恢复提示、请求完成不意味着全部允许、不可用/空范围不请求系统、失败可重试、活动数据禁止写入、通知拒绝/失败可恢复、旧通知状态查询不能覆盖较新请求结果。另覆盖健康请求日期持久化与可写状态刷新。

界面 8 项：

1. 跳过健康连接并访问五个 Tab。
2. 热量 0 被拦截 → 清除后填 2200 → 收起键盘 → 完成引导 → 重启保留。
3. HealthKit 不可用时仍能返回并完成首次使用。
4. 申请身体数据写入后显示 0 / 2 可写，不出现“已同步”。
5. 通知拒绝后返回并进入训练页。
6. 健康请求失败后保留重试按钮与返回导航。
7. 从首次使用进入隐私说明，再返回完成引导。
8. 最大辅助字体与深色模式下到达主要入口。

真实系统场景 2 项：隔离的全新模拟器中使用原生 HealthKit 和 UserNotifications，打开系统页面并选择不允许，完成系统说明后返回 App，继续导航。没有查询或写入健康样本，没有个人健康数据参与测试。App 使用简体中文，模拟器系统页面使用英文；拒绝按钮保留中文匹配项，中文系统环境仍需设备验证。

## 本轮修复与复查

| 问题 | 修复与验证 |
|---|---|
| 大字体下固定的引导标题挤压表单 | 标题与设置项一同滚动；大字体 UI 场景通过 |
| 首页或引导隐藏导航栏影响子页返回 | 偏好、隐私与健康子页显式显示导航；返回场景通过 |
| 数字键盘缺少清楚的收起与清空路径 | 添加完成与清除；输入栏在聚焦时通过安全区挂载，断言只有一个完成按钮，触控高度至少 44pt |
| 键盘工具栏初始布局告警 | 改用安全区输入栏，最终全部 10 项 UI 场景无尺寸告警 |
| 请求期间范围可能变化 | HealthKit 请求期间锁定范围与请求按钮 |
| 返回系统设置后可写状态过时 | 重新检查上次请求范围中的写入授权；不检查或推断读取拒绝 |
| 较早的通知状态查询覆盖较新请求结果 | 用操作版本丢弃过时结果；异步回归测试通过 |
| iOS 27 Tab/返回控件结构变化 | 测试使用实际语义按钮与系统 BackButton，不假定固定 TabBar 层级 |

按 ce:review 在主线程顺序复查了正确性、测试、维护性、项目规则、权限安全与异常恢复。产品代码没有网络请求、第三方运行时依赖、敏感日志或研究目录引用。本轮不是独立人工审计。

## 仍需真机验收

- 配置 Developer Team 和商用/开发 Bundle ID，连接 iPhone 后完成启动与五个 Tab 检查。
- 最低支持系统和常规小屏设备上的显示、键盘、安全区与深浅色。
- VoiceOver 实际播报、焦点顺序、手势及减少动态效果。
- 系统设置中撤回和部分授权后返回 App，通知状态刷新、Health 写入状态刷新；读取权限仍不作拒绝推断。

这些是 U1 的剩余设备验收项，不能用模拟器或 mock 宣称已完成。当前不具备 TestFlight 或商业发布条件。

## 复现与运行观察

构建、测试命令见 [README](../../README.md)。真实系统权限测试应在全新模拟器上运行，避免已处理过权限导致系统不再显示弹窗。重复页面/基础服务测试可以在原设备运行；不要清除用户自己的设备数据。

正常信号：引导可跳过权限；保存后重开数值一致；拒绝权限仍能返回；不出现虚构同步成功。异常信号：启动崩溃、已保存偏好丢失、授权后长期停留在请求中、出现多个键盘完成按钮或主要操作无法触达。发现时保留测试结果与截图，暂停交付并回退最近的界面/服务改动；不要清空用户偏好作为修复办法。

本轮未发布，没有生产监控服务。后续每次修改基础服务运行对应单元测试；修改页面运行对应 UI 场景；接入 U2/U6 时重新审阅隐私与健康状态合同。Xcode 的 AppIntents 元数据跳过提示仅因项目没有 AppIntents 依赖，不影响当前功能。

## 证据与截图

[结构化测试结果](phase-one-results.json) 保留最终数量、设备、起止时刻与告警列表。完整 xcresult 和日志在 `app/build/`，属于本机验证产物，不打包进 App。

| 画面 | 文件 |
|---|---|
| 欢迎 / 今天 | [欢迎](screenshots/iphone-01-welcome.png)、[今天](screenshots/iphone-02-today.png) |
| 训练 / 饮食 / 趋势 / 我的 | [训练](screenshots/iphone-tab-training.png)、[饮食](screenshots/iphone-tab-nutrition.png)、[趋势](screenshots/iphone-tab-trends.png)、[我的](screenshots/iphone-tab-settings.png) |
| 权限边界 | [部分写入权限](screenshots/iphone-health-processed.png)、[设备不可用](screenshots/iphone-health-unavailable.png)、[请求失败](screenshots/iphone-health-failed.png)、[通知拒绝](screenshots/iphone-notification-denied.png) |
| 系统真实弹窗 | [HealthKit](screenshots/iphone-system-health-sheet.png)、[通知](screenshots/iphone-system-notification-alert.png) |
| 深色与最大辅助字体 | [欢迎](screenshots/iphone-welcome-accessibility-dark.png)、[设置](screenshots/iphone-settings-accessibility-dark.png) |

截图为 iOS 27.1 / iPhone Duo 的实际输出，右侧导航与状态区域由系统提供。
