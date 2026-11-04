---
title: "feat: Leanora Fitness 1.4 日历复盘与记录复用"
type: feat
status: active
date: 2026-11-03
---

# Leanora Fitness 1.4（8）版本计划

## 目标与范围

承接已经送审的 1.3（7），让用户从“完成记录”走向“查看变化、复用下一天”。参考训记公开的训练分析、动作资料和历史记录体验，以及薄荷公开的多维记录和回顾体验，独立实现以下三个完整流程，并补充原创离线内容。沿用原生 SwiftUI、SwiftData 与现有 HealthKit 队列。

本轮不引入账号、云端 AI、拍照识别、付费、饮水新类型或自动处方。现有 882 个动作及图示、500 条食品保持来源和许可；不复制竞品数据、文章、截图或视觉资产。日历只统计本机业务记录，Apple Health 来源页继续承担外部样本展示与去重。

## 需求追踪

- R1：训练、饮食与身体记录按本地发生日期集中回看；7 天概览有明确的记录覆盖口径。
- R2：一个动作可查看逐次正式组表现、最近两次差异和真实来源训练；不同记录类型分别计算。
- R3：整日饮食可选餐次、预览、取消、确认复制；保留营养快照和未知值，提交失败可重试。
- R4：增加 4 篇原创训练复盘指南、4 篇原创饮食回顾指南；离线可读且从相应功能可达。
- R5：完整回归、真实截图、签名发行和商店介绍与实际功能一致；提交 1.4 审核，审核后手动发布。

## 调研依据与现有模式

- [训记官方 App Store](https://apps.apple.com/cn/app/id1464915553)：训练记录、数据分析、动作讲解和身体数据。公开说明仅用于功能研究。
- [薄荷健康官方 App Store](https://apps.apple.com/cn/app/id457856023)：饮食、运动、身体多维记录和回顾。公开说明仅用于功能研究。
- `analysis/训记与薄荷-开发参考.md`：先前的页面与数据模型研究；作为历史资料，不将旧版提取数据作为本轮内容素材。
- `app/ios/Leanora/Core/Analytics/TrainingSummary.swift`：仅完成训练、已完成外部负重正式组计容量；其他类型独立呈现。
- `app/ios/Leanora/Core/Nutrition/NutritionCalculator.swift`：未知营养素保留 nil，缺少日期不当作零摄入。
- `app/ios/Leanora/Core/Nutrition/NutritionRepository.swift`：依赖数据与 Health 写入意图原子提交；组合餐使用稳定 UUID 重试幂等。
- `app/ios/Leanora/Features/Today/TodayView.swift`、`Features/Body/TrendsView.swift`：新增复盘入口，保留现有主记录入口。

## 技术决策

1. 新统计为现有记录的纯函数投影，不增加 SwiftData 实体、不改变备份格式 2。编辑、删除后刷新即重算，不保存容易过时的统计副本。
2. 日历采用按周浏览的 7 日按钮与日期选择器，可前后逐周与回今天；选中日显示训练、四餐、身体数据和直达记录入口。文字标记与辅助标签同时表达记录类型，不仅靠颜色。
3. 周回顾展示训练天数/次数/组数、饮食有记录天数、完整营养记录天数和仅有记录日期的已知热量均值。明确“有记录不等于全天完整”；不打健康分、不推导热量缺口。
4. 动作历史按 UUID 和当前记录类型筛选，只取已完成训练中的已完成正式组；同次重复动作合并为一次训练记录，显示真实组与备注。外部负重呈现容量与最高实际负重；自重/辅助分别展示次数（辅助负重不转为正向 PR）；计时/有氧展示实际秒数/距离。最近两次差异只比较相同类型，不估算 1RM。
5. 整日复制从冻结的原始快照创建独立记录，选餐次并按相同本地钟点映射到目标日期（DST 使用系统日历匹配），目标日原记录保留。预览最多 200 项，无记录、同一天、无餐次、日期/时区非法均拒绝。批次生成一次并保留至成功或参数变更；取消与预览零持久化。仓储沿用单餐记录事务但独立允许 200 项，整批已存在且相等则成功返回，部分重放或篡改重放拒绝。
6. 入口：今天/趋势 → 日历复盘；动作详情/训练中指导 → 动作历史；饮食日记/选中日详情 → 复制整日饮食。保留原有单餐复制与组合餐。

## 实现单元

- [x] **U1：日历与周回顾核心计算**（R1）
  - 新建 `app/ios/Leanora/Core/Analytics/JournalReview.swift`。
  - 测试 `app/ios/LeanoraTests/JournalReviewTests.swift`。
  - 场景：跨月/跨年/夏令时连续 7 个当地日期；完成/放弃/软删除训练；无饮食日期不平均为零；部分营养未知的完整性；身体记录同日取最后一次；导入时区不按当前时区重新分日。

- [x] **U2：单动作历史与比较**（R2）
  - 新建 `app/ios/Leanora/Core/Analytics/ExerciseProgress.swift`、`Features/History/ExerciseProgressView.swift`。
  - 修改 `Features/Training/ExerciseLibraryView.swift`、`ExerciseGuidanceView.swift`。
  - 测试 `app/ios/LeanoraTests/ExerciseProgressTests.swift`。
  - 场景：同次多个动作条目合并、热身/未完成/放弃/删除排除；旧类型排除；kg/lb 展示；没有上次不造差异；外部负重、自重、辅助、计时、有氧分别验证；来源历史可打开，编辑后重算。

- [x] **U3：整日饮食复制事务和预览**（R3）
  - 新建 `Core/Nutrition/DietDayCopy.swift`、`Features/Nutrition/DietDayCopyView.swift`。
  - 修改 `Core/Nutrition/NutritionRepository.swift`、`Features/Nutrition/DietDiaryView.swift`。
  - 测试 `app/ios/LeanoraTests/DietDayCopyTests.swift`。
  - 场景：选择两餐、食品/快捷热量混合、原快照与未知宏量保留、新 UUID 与时刻归属；源数据后续变化不影响冻结预览；同日/空餐次/超过 200 项拒绝；保存失败无数据和 Health 孤儿任务；相同批次重试无重复，部分或变更重试拒绝；原数据不改且备份恢复一致。

- [x] **U4：日历页面、主入口与原创内容**（R1、R4）
  - 新建 `app/ios/Leanora/Features/History/JournalReviewView.swift`。
  - 修改 Today/Trends 页面、训练与饮食内容 JSON、对应内容测试；补充 `app/docs/review-workflow-1.4.md` 和来源说明。
  - 测试 `app/ios/LeanoraUITests/ReviewWorkflowTests.swift`，更新 `StoreScreenshotTests.swift`。
  - 场景：前/后周、今天恢复、空日、选择日后打开训练与饮食、整日复制取消/保存/重启、动作历史入口；深色/大字体至少一条完整流程；8 篇原创内容可读；日期按钮 44pt 最小触控与有意义辅助标签。

- [ ] **U5：回归、发行、商店与审核**（R5；依赖 U1–U4）
  - 版本 1.4 构建 8；在保留已有用户改动的工程上精确增加文件和版本设置，不覆盖整个工程。
  - 核心全套测试 + 定向原生 UI 回归 + 食品/动作目录验证 + Release 签名导出审计。
  - 生成实际原生界面商店截图，保存中英文新功能/介绍与公开审核说明；只在 Apple 已有私有表单保留审核联系人。
  - 记录 Apple 实际构建验证与送审状态；若旧版本仍占用审核流程，先完成新构建再依据具体状态处理，不将“已上传”写成“已送审”。

## 系统影响、风险与验收

- 读路径：仓储快照 → TrainingStore/JournalStore → 纯统计 → SwiftUI；失败通过现有 error notice 显示。
- 写路径：复制参数 → 冻结预览 → 稳定批次 → 单个 saveWithHealthIntent → 刷新日记；失败保留预览与批次供重试。重启未提交草稿不恢复，不静默写入。
- 备份与 Health：无新业务类型/权限/采集；现有 format 1/2 读取与 format 2 写出继续兼容；Health 已知组件排队逻辑不变，新增复制产生独立业务 UUID。
- 性能：日历仅投影所选 7 日；动作历史仅筛选目标动作；避免在每个日历格重复遍历完整记录。容量/计数重算使用实际数据，无网络下载。
- 发行依赖：Chrome 的 Apple 登录当前已过期，已请用户登录；不阻碍实现与本地验证。Xcode 账号与签名是否有效留到发行验证。
- 现有未提交的工程整理、Info.plist 排版和 Localizable.xcstrings 属于工作区基线，先留存字节备份；只提交本轮明确修改，不擅自丢弃。
- 验收证据存入 `app/docs/qa/review-workflow-1.4/` 与 `app/store/app-store-release-1.4-8-20261103.json`；不会用模拟器结果代替真实设备 HealthKit、VoiceOver 或 App Review 的通过证明。

## 计划复核

已从功能、交互、数据一致性三个角度顺序复核：按历史 localDate 聚合、按 measurement 区分比较、冻结预览稳定 UUID、整批事务回滚和公开资料范围均有对应验收场景。无阻塞产品选择。实施时记录 UI 实测和 Apple 外部状态，不预设审核结论。

## 2026-11-03 实施进度

U1–U3 核心功能已实现并通过真实仓储/事务测试。U4 页面、入口、8 篇内容和 4 个原生 UI 流程测试已实现，全部测试目标可编译；UI 执行被 Xcode 27.2 与 CoreSimulator 版本不匹配阻断，尚无 1.4 截图。U5 开发签名归档成功，发行导出返回 No Accounts/缺少匹配私钥，尚未上传或送审。Mac 锁定且 Chrome Apple 会话过期，已向用户请求解锁/登录；计划保持 active，不把上述外部步骤标为完成。完整证据见 `app/docs/qa/review-workflow-1.4/verification.json`。

## 2026-11-04 验证进度

U4 已完成：日历改为自适应日期网格，图表提供日期与数值标签，未知有氧距离不再补零或生成差值。核心 150 项执行、148 通过、2 项既有容量测试跳过；10 个原生用例在第 4、6、7 批最终通过。训练、饮食、备份导入、大字体深色及持久化均有实际证据；早期脚本和环境失败未隐藏，未声称一次全套全绿。14 张本版本截图生成并校验，双语文案已保存到 1.4 草稿。最终 RC2 归档成功，尚待发行导出、上传和正式送审；U5 保持未完成。当前回执改用 `app/store/app-store-release-1.4-8-20261104.json`。
