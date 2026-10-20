# 阶段 4、5 验证

2026-10-20。范围：U4 训练执行/计时/恢复/历史/统计，U5 饮食/身体/首页/趋势。独立原生实现，未移植 OpenGym、训记或薄荷的代码及内容库。

## 结果与证据口径

- SwiftPM：**76 项通过**，0 失败，日志 `app/build/u45-core-complete.log`。
- 原生全量回归：104 项中 103 通过、1 项饮食连续操作失败，见 [原始完整结果](phase-four-five-full-run.json)。该失败保留，不把此轮描述为全通过。
- 最新生产代码定向回归：82 项中 81 通过、1 项仍为同一模拟器坐标问题，包含全部最新 76 项原生单元及 6 项 U4/U5 UI，见 [定向原始结果](phase-four-five-regression-run.json)。
- 用录屏核对后，修正自动化的滚动几何同步与完整可见性判断；连续饮食原生用例最终通过，见 [饮食复测结果](phase-four-five-diary-results.json)。验证 150 g 米饭为 195 kcal，快速记录 100 kcal，复制早餐后合计 490 kcal，重启和首页一致。
- 上述结果按测试方法取最新状态，覆盖 **76 项单元 + 29 项 UI，共 105 项通过**。这是全量回归加修复后定向复测的合并覆盖，**不是单轮 105 项全通过**。各原始 JSON 均保留失败和重跑记录；所列结果没有跳过或运行时告警。
- 真实通知允许与系统待送达排程使用另一台隔离模拟器单独验证，见 `phase-four-five-notification-results.json`。该用例只证明实际授权及系统请求存在，不能证明横幅/锁屏送达。
- 最终 iPhone Release 构建成功：`app/build/U45Release`、`app/build/u45-release-complete.log`；[资源和调试隔离审计](phase-four-five-release-audit.json)。未商业签名、未上传 TestFlight。

原始 Xcode 结果：`app/build/U45Verified.xcresult`（完整回归）、`U45FinalRegression.xcresult`（最新功能定向）、`U45DiaryGeometry.xcresult`（饮食通过）、`U45NotificationScheduling.xcresult`（独立真实通知排程）。构建产物不入 Git，结构化结果与精选原始截图入库。

## 环境

Xcode 27.1，Swift 6，iPhone Duo / iOS 27.1 模拟器，最低目标 iOS 18。

- 主验收设备：`CEF115CA-99D4-4251-9636-45DC1815F56A`，Leanora U45 Final。
- 通知允许设备：`C1FB3E64-E850-4CBF-A7CD-E2B697274A20`，Leanora U45 Notifications。
- 真正的系统健康/通知拒绝用例包含在全量回归；与通知允许用例分开安装运行，避免授权状态互相污染。
- 数据损坏 fixture 故意触发 Core Data 无法打开的错误日志，用于证明保留原库；不属于生产运行告警。构建器的 AppIntents 元数据无依赖提示不是测试运行时告警。

## 功能对应

| 范围 | 实际验证 |
|---|---|
| 逐组记录 | 负重/次数/时长/距离、组类型、RPE/RIR 的原值校验；明确保存与完成；实际值不足不能完成 |
| 计划与预填 | 计划快照不改；最近完成值预填但不自动完成；同动作两个模板项目的预填独立 |
| 原子持久化 | 逐组保存、过期修订拒绝；完成与健康意图失败同时回滚，重复结束不增版本或任务 |
| 暂停与计时 | 动作与休息互不混用；暂停累计、继续重启原计时；真实磁盘重开及 UI 杀进程后恢复同 UUID |
| 跨日与历史 | 训练按开始日计一次；更正开始时间平移相关时刻而保留时长；原生编辑历史组后容量由 160 重算为 200 kg·次 |
| 超级组 | 模板原生配对保存到训练快照；两个动作同轮完成才启动休息；与热身/正式组分类分开 |
| 统计 | 未完成、放弃、热身、自重、辅助及非正式组不混入正式负重容量/PR；编辑/删除来源组重新计算 |
| 系统提醒 | 截止时刻恢复、到期不重排、终态取消；实际允许及系统请求验证；拒绝保留前台路径；未来安排考虑改期和已开始状态 |
| 离线食物 | 300 条官方来源，ID/范围/来源/份量有效，中英文搜索；自定义、归档和来源可见 |
| 数量与单位 | 100→150 g 已知营养同比 1.5 倍；来源明确的份单位，kJ/kcal、kg/lb；零/负/非有限/超范围拒绝 |
| 饮食快照 | 自定义食品修订不改历史；快速热量保留未知宏量；复制新 UUID；编辑删除与最新组件意图同步更新 |
| 日汇总与目标 | 餐次/全天/首页同口径，缺失不是零；按历史生效日期取目标；不自动加运动消耗 |
| 身体与趋势 | 原生新增同日两次体重均保留；体脂范围、编辑删除、备份；每日末次值/均值、7/30 天与 PR 口径 |
| 既有回归 | 偏好、真实权限、事务/迁移/恢复/备份、动作库/模板/周安排均回归通过 |

## 问题修复与限制

1. JSON 毫秒往返可能有亚毫秒浮点差异：持久化返回使用规范化值，保存开始时刻比较采用 1 ms 容差，并保持时区和归日一致。
2. 暂停状态缺失暂停区间可能导致结束时越界：校验并拒绝损坏记录，结束路径另有防护及测试。
3. 通知刷新重入可能让旧截止覆盖新截止：两个提醒服务都串行合并最新请求。
4. 饮食新增/快捷/复制/编辑统一弹窗，关闭完成前阻止再次打开；身体新增/编辑同样统一。偏好目标和备份恢复后主动刷新日记缓存。
5. Duo 的弹窗关闭后，录屏中的滚动位置与辅助功能坐标出现偏移；测试显式滚动更新几何，并避免点击屏幕底部只露出一部分的按钮。原始失败、录屏和最终通过结果均保留。
6. 大字体日期控件在窄屏溢出：独立大字体标题，系统日期控件限制到 xxxLarge；其余正文遵循完整 Dynamic Type。
7. Duo 模拟器按 Home 后黑屏且不可靠报告后台状态，横幅无法可靠观察。先前后台送达尝试失败，不计入通过；最终通知用例只验证真实授权及系统排程。**后台/锁屏送达、专注模式、物理数据保护、最低系统和 VoiceOver 仍需真机。**

HealthKit 样本读取/写入、去重和恢复核对继续属于 U6/U7。本阶段意图为持久化待处理数据，不执行样本导出。300 条食物有来源与重建证据，其中 29 条中文名；中国餐饮/品牌覆盖、专业营养复核、22 条动作的教练复核仍是商业发布依赖。没有账号、云同步或健康数据上传。

## 截图

[暂停/休息](phase-four-five-screenshots/u4-paused-set-rest.png) · [强退恢复](phase-four-five-screenshots/u4-recovered-session.png) · [历史容量重算](phase-four-five-screenshots/u4-history-edited-volume.png) · [超级组](phase-four-five-screenshots/u4-superset-snapshot.png) · [动作计时](phase-four-five-screenshots/u4-duration-complete.png)

[来源/份量](phase-four-five-screenshots/u5-food-source-portion.png) · [日记重启](phase-four-five-screenshots/u5-diary-recovered.png) · [首页合计](phase-four-five-screenshots/u5-today-summary.png) · [同日多测量](phase-four-five-screenshots/u5-multiple-body-records.png) · [身体营养趋势](phase-four-five-screenshots/u5-body-nutrition-trends.png) · [大字体深色校验](phase-four-five-screenshots/u5-quick-validation-large-dark.png)。已人工查看关键原始截图，来源、合计与部分缺失标识可见。
