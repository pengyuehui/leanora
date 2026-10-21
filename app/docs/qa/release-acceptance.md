# Leanora 0.2 首版实现与发布验收

更新：2026-10-21。源码完成 U6–U8 的本机部分及记录体验调整；**没有签名发布 TestFlight，也没有把模拟器结果计作物理验收**。工作分支 `feat/offline-workout-nutrition`，此前基线 `eeb41ff`。

## 本次交付

健康：真实授权/受限历史、500 条分页与原子游标/删除、重授权代次、观察器、日统计、逐组件幂等写入/编辑/删除、失败重试、手动移除抑制、恢复核对和版本下限、停止及在途写入等待、外部只读/隐藏和训练主来源关联。只在查到真实样本及不低于期望的版本后确认写入，不把暂存 UUID 当成健康保存凭据。

数据：JSON/CSV 单一系统导出入口，含时间的文件名避免覆盖当天备份；CSV 保留未知值空白并防公式执行。导入有预检与恢复门槛。清缓存、清本机和删 Health 副本三个独立操作；清本机需要输入确认，保留 Health 原始样本及另行导出文件。

体验：浅灰/白、蓝色操作强调；首页先展示训练/记餐；训练逐组对齐、完成符号与固定结束/休息入口；饮食日期切换、顶部快捷菜单和最近食物；深浅色与大字体回退。100 个原创基础动作名/别名与 300 个 USDA 基础食物；完整品牌/中餐库、动作教学媒体及专业内容签名不在已获得内容之列。

## 验证结果与口径

- 100 个核心方法（含 2 个 iOS 协调器方法与 2 个单独容量方法），34 个原生 UI 方法，按最新非跳过结果合计 **134 个独立方法通过**。这是全量回归加修复后定向复测及独立权限安装的覆盖，**不是单次全绿的 134 项运行**。最新每方法结果和所有原始轮次分别保留在 [聚合结果](u678-latest-method-results.json) 与 [运行历史](u678-test-history.json)。
- SwiftPM 常规运行 98 项：96 通过、2 项容量显式跳过；容量另行实际执行。iOS 宿主运行 100 项：98 通过、2 项容量显式跳过。故障测试使用真实 SwiftData actor/事务与可控传输适配边界，覆盖 1000 样本中断/重试、写入成功但确认失败、营养未知删除、局部权限、手动删除、版本替换、恢复版本下限、后台写入与清理竞态。
- 真实 SDK 模拟器：系统选择 5 个读写项、Continue、过去 30 天及未来数据，再最终 Allow；新增 65.4 kg 本机测量，待处理 0、失败 0、实际关联 1，重新检查仍为 1。首次授权见 [原始结果](u678-health-limited-history-summary.json)，最终严格写入确认版本再次通过，见 [最终 SDK 结果](u678-confirmed-health-write-summary.json) 和 [来源状态截图](u678-screenshots/u678-system-health-write-echo.png)。SDK 系统拒绝与通知允许/拒绝在独立安装上运行，不能混用相反权限结果。
- CSV 系统导出面板、输入确认重置、真实 JSON 保存→重新选择同一文件→新增 0、导入新增 1→重启保留，均取得通过结果。大字体深色健康页原生 contrast/textClipped audit 通过；VoiceOver 实际听读保留物理验收。
- Release iPhone Archive 已构建，运行时没有第三方依赖。100 动作/300 食物和权限/隐私清单存在，调试启动标记及失败注入不在正式可执行文件中。原开发标识包保留 [历史审计](u678-release-audit.json)；正式标识的后续构建见 [新包审计](fitness-release-audit.json)。当前未签名 Archive 位于本工作区 `app/build/ReleaseCandidate/Leanora-0.2-Fitness-Unsigned.xcarchive`，不提交二进制与开发缓存。

## 容量实测

本机 macOS 27.0.1、Xcode 27.1/Swift 6.4；原生测试为 iOS 27.1 iPhone Duo 模拟器。两项容量通过：1 万训练组 + 1 万饮食、CSV 约 3.82 MB；10 万外部健康样本按 500 条/批共 200 批导入，实际约 100 秒。详见 [原始容量日志](u678-capacity.log)。

发现整库重复解码约 0.59 秒后，为单写入 actor 增加事务失效的不可变业务快照缓存；同一批数据后续快照约 0.02–0.03 毫秒，首次冷读取仍约 0.59 秒。健康导入与元数据分离，缓存界面只读 100 条页面，逐组件任务使用直接索引。补强测试在约 100 秒导入期间持续发起 4112 次 MainActor 探针，等待时间 p95 约 0.059 毫秒、最大约 13.3 毫秒，见 [原始探针日志](u678-capacity-main-probes.log)。这些桌面值不能替代最低支持 iPhone 的 p95 <300ms 目标验收。

## 原始失败与修复

全量运行存在系统文件按钮旧类型/坐标、表单结果滚出屏幕、页面改版后旧目标定位、键盘遮挡确认以及系统 Health 表格/Continue/历史范围的自动化失败，原始失败 JSON 不删改。修复了真实可用性问题（单一导出器、唯一文件名、反馈滚动、顶部清除与完成输入）；测试按实际控件类型/表格/系统历史选择重定向，随后分别复测。失败轮次没有改写成成功；`u678-three-retests` 的 Health 失败由后续受限历史成功轮次覆盖。

## 未完成的外部发布门槛

`devicectl` 只列出模拟设备，无物理 iPhone。最低 iOS18 与当前稳定系统真机的外部训练/全营养组合、多来源统计、时区/夏令时、锁屏/后台、真实通知横幅与文件保护、VoiceOver 听读仍待 [设备矩阵](healthkit-device-matrix.md)。内容目录尚需教练/营养审核人落实并签名。

发布者已指定 `ai.leanora.fitness` 和 Manyao Li 团队，本机 Xcode/证书核实 Team ID 为 `8ZP3NMT2A8`。工程配置完成，正式标识下的真实 HealthKit 授权/写入/重复检查及未签名 Archive 通过。签名尝试被 Apple `PLA Update available` 拒绝，需账号持有人处理最新协议后重试获取描述文件。政策公开 URL、运营主体及联系邮箱仍待补充；未签名 Archive 不是 TestFlight 安装包。后续见 [发布身份记录](release-identity.md) 与 [发布清单](../release-checklist.md)。

## 重现

普通核心：`swift test --package-path app --scratch-path app/build/SwiftPM --disable-swift-testing`。容量：设置 `LEANORA_SCALE_TESTS=1` 并过滤 `CapacityTests`。

功能 UI 回归需排除四个相反/首次系统权限方法，另在新模拟器运行 Health 允许闭环、Health/通知拒绝（同一个新安装可做）及通知允许排程（第三个安装）。具体方法为 `HealthReleaseExperienceTests/testSystemHealthAllowedWriteAndEcho`、`OnboardingTests/testSystemHealthSheetCanBeDismissedAndAppRemainsUsable`、`OnboardingTests/testSystemNotificationDenialKeepsAppUsable`、`WorkoutRecoveryTests/testSystemRestReminderAuthorizationAndScheduling`。真实 Health 允许用例兼容已授权重试；本次首次完整授权证据仍单独保存。

`bash app/scripts/archive_release.sh <一个尚不存在的 Archive 路径>` 只在本机生成未签名候选包，不上传或操作开发者账号。
