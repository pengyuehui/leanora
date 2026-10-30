---
title: feat: Leanora Fitness 1.3 饮食记录效率与内容升级
type: feat
status: active
date: 2026-10-30
---

# Leanora Fitness 1.3 版本计划

目标：让用户更容易找到食物、核对份量、保存常吃的一餐，并读懂当天记录。先发布本计划，再实现 U1–U6、验证和提交 App Store。计划版本 1.3，下一构建号 7；正式送审以 Apple 页面实际接收状态为准。

## 参考与问题

薄荷官方介绍体现食物查询、饮食记录、营养反馈和健康数据记录的连续流程；已有 [开发参考报告](../../analysis/训记与薄荷-开发参考.md) 进一步记录了收藏、餐别、份量、快速热量和失败回退的静态证据。静态页面声明不等于已验证的当前线上流程，本轮据此独立设计。

Leanora 当前已有 300 条 USDA 食品、29 个中文名称、来源份量、自定义食物、快速热量、历史餐次复制、历史目标和 Health 同步。主要缺口是中文检索覆盖有限、最近仅首屏 6 条、没有食物收藏和可编辑的组合餐，份量页的来源文字压过输入，日记反馈仍需用户逐项阅读解释。

| 参考价值 | 本轮交付 |
| --- | --- |
| 查找、收藏与反复记录 | 中文目录扩展；全部/收藏/最近/自定义与分类、搜索组合 |
| 食物份量和历史复用 | 快捷克数、明确选用上次克数、实时营养预览；保留有来源的份量换算 |
| 常吃的一餐 | 多项食物组成可编辑的组合餐，保存后按份数一次记录独立明细 |
| 内容帮助完成记录 | 6 套原创食物搭配范例、8 篇离线记录指南 |
| 每日营养反馈 | 日记总览、各餐汇总、未知营养计数和已有目标差额就近呈现 |

## 需求与边界

**内容与查找**

- R1：目录扩展至 500 条、至少 150 个独立中文名称，保留原 300 个食物 ID、营养值、份量 ID 和历史引用。中文名保留生熟和加工状态；英文原名可检索。数字逐项来自 USDA 官方 SR Legacy 原文件，不补算缺失营养，不引入薄荷目录。
- R2：食物可收藏；最近最多 20 个，按未删除饮食记录去重；搜索与分类、收藏/最近/自定义筛选共同生效，归档食物不会混入默认结果。收藏进入 JSON 备份。

**记录与反馈**

- R3：份量页优先显示名称、数量、餐次、食用时间和营养预览；可选 50/100/150 g，或明确选用上次克数，保存前可修改。现有来源单位仍可选择；来源移至可展开区。编辑旧记录继续按原快照换算。
- R4：可新建、编辑、复制和删除组合餐，也可把某日某餐存为未保存草稿。组合最多 50 项，支持食物与快速热量快照、重复食物、备注；按正数份数预览后明确记录，生成独立饮食记录与既有 Health 任务，不修改历史或原组合。
- R5：提供 6 套原创搭配范例和 8 篇离线指南。范例展示实际食物、克数、计算来源和营养缺失；预览零写入，采用后进入可编辑的组合草稿，明确保存或记录才写库。
- R6：日记按日期→营养总览→快捷记录/组合餐→四餐明细组织。标明已知合计、缺失条目及已有热量目标差额；目标不被运动消耗自动增加，不把空白一天称为零摄入或把记录齐全称为饮食达标。

**兼容与交付**

- R7：旧记录、模板、身体数据和健康队列稳定；新组合通过现有本地事务保存，JSON 恢复包含它们。无账号、内容联网、追踪、新权限或第三方健康传输。
- R8：完成基础与原生 UI 验证，更新双语介绍和真实截图；按既定格式提交并推送 GitHub，正式签名、上传、核验并提交审核，保留免费和审核通过后手动发布。

本轮聚焦个人离线记录。不实现拍照识别、条码在线库、减重处方、自动营养评分、社交、商城或智能秤；这些需要独立的数据、服务或设备合同。搭配范例是记录示例，不是个体饮食方案。新增内容以中文提供，部分 USDA 名称和来源单位仍为英文。

## 数据与交互决定

1. **目录与用户状态分离合并。** `Food` 增加可选收藏/分类信息，旧 JSON 缺失可以解码。目录升级不重写历史 `FoodSnapshot`。对于已持久化的基础食物，以新目录提供检索名/别名/分类、保留本地修订/收藏/归档和既有营养及单位，避免旧缓存遮蔽中文检索。自定义资料保持用户输入。
2. **组合餐独立于食物。** 新增 `MealTemplate` 与有独立 ID 的条目，保存名称、顺序、数量/单位、克数、营养和可选食品快照。它不冒充每 100g 食物，也不把缺少克数的快速热量变成配方重量。组合展示按保存时快照，不随食物资料修改而变化；归档来源食物不破坏已保存组合。
3. **按份数缩放快照。** 基准一份就是保存的整组内容；份数在 0.01–100 范围内，缩放后仍需通过全部数值边界。未知值保持未知；重复食物保留独立条目。一次确认在一个事务中保存全部新记录及健康任务，失败不产生半餐。事务不调用 HealthKit；既有队列后续异步同步。
4. **保存与摄入分开。** 预览和编辑草稿不记入日记。保存组合仅写组合及所需食物依赖，无 Health 任务；“记录这份组合”才写当次饮食。重复点击提交时沿用同一批草稿 UUID，禁用保存中操作，成功后关闭；重启从已保存组合重新建立新草稿，不自动重放。
5. **继续使用现有 StoredRecord。** 增加业务枚举类型，不增加 SwiftData 实体。JSON 新导出版本为 2，读取版本 1 和 2；旧备份缺失新增可选字段保持默认，版本 1 不接受新组合类型。旧客户端对版本 2 明确拒绝，避免不完整恢复。JSON 是组合的恢复格式；原 CSV 继续导出实际记录。
6. **真实的反馈。** 继续复用 `NutritionCalculator`、`NutritionSummary` 和生效日期目标，增加明确的各餐与缺失数量反馈。没有营养处方、补零或由 4/4/9 公式替代来源热量。食物来源的静态营养值和包装/实际份量不保证所有地区或烹调成品相同。

主要流程如下；此图用于说明边界与状态，不是实现代码。

```mermaid
flowchart LR
 A[日期与餐次] --> B[搜索 / 收藏 / 最近]
 B --> C[数量与单位，实时预览]
 C --> D[明确保存饮食]
 A --> E[我的组合 / 原创范例]
 E --> F[未保存组合草稿]
 F --> G[保存为我的组合]
 G --> H[选择份数与餐次，预览]
 H --> D
 D --> I[本地事务：明细与健康任务]
 I --> J[日记反馈]
 I --> K[既有 Health 队列]
```

## 实施单元与验收

- [x] **U1：官方食品目录和中文检索资源（R1、R7）**

文件：修改 `app/scripts/build_food_catalog.py`、`app/ios/Leanora/Core/Domain/NutritionModels.swift`、`Core/Nutrition/FoodCatalog.swift`、`Resources/Catalog/foods.json`、`app/docs/food-catalog-manifest.json`；新增 `app/content/food-localization.json`、`app/scripts/validate_food_catalog.py`；测试 `app/ios/LeanoraTests/NutritionCalculationTests.swift`、新增 `FoodCatalogTests.swift`。

沿用官方 ZIP、稳定 UUID 和原始营养 ID 映射；增加人工独立编写的中文名/别名和来源分类。保留旧 300 条全部数据，增加常见食品后按固定规则补足 500，留下源 SHA-256、许可和逐项校验。分类有未分类回退；资源错误明确报错。

场景：500 条唯一 ID、至少 150 中文名；旧 300 的营养和单位逐字一致；米饭与生米、鸡蛋与蛋清不混同；中文/英文/多词检索；缺失分类可读；未知营养不补零；恶意/重复 ID 和错误单位拒绝；原目录食物持久化后升级仍能搜到新别名且历史不变。

- [x] **U2：收藏、最近与份量主流程（R2、R3、R7；依赖 U1）**

文件：修改 `Core/Nutrition/NutritionRepository.swift`、`Features/Nutrition/JournalStore.swift`、`FoodSearchView.swift`、`FoodPortionView.swift`；新增 `Core/Nutrition/NutritionWorkflow.swift`；测试新增 `app/ios/LeanoraTests/NutritionWorkflowTests.swift`、`app/ios/LeanoraUITests/NutritionWorkflowTests.swift`。

沿用动作收藏的幂等和修订模式；收藏不产生健康任务。筛选使用原生可换行控件，收藏入口有文字语义。最近按时间与稳定 ID 排序，删除记录不再贡献最近。份量操作直接改变输入并预览，切换单位时重置到明确数量，防止把 100g 误读为 100 份；上次克数仅作为可选择操作。错误保留输入，空筛选有返回全部的出口。

场景：收藏/取消/重启/备份；搜索+分类+收藏组合；删除/归档后的最近过滤；首次食物 100g、上次明确复用、快捷克数切回 g；单位乘积、零/负数/NaN 拒绝；编辑历史不读新营养；注入失败收藏和饮食不变；超大字号、深色模式按钮可达。

- [x] **U3：组合餐、备份及事务（R4、R7；依赖 U1、U2）**

文件：新增 `Core/Nutrition/MealTemplate.swift`、`Features/Nutrition/MealTemplateView.swift`；修改 `Core/Domain/BusinessRecord.swift`、`Core/Nutrition/NutritionRepository.swift`、`Core/Backup/BackupService.swift`、`Features/Nutrition/JournalStore.swift`、`FoodSearchView.swift`、`FoodPortionView.swift`；测试新增 `app/ios/LeanoraTests/MealTemplateTests.swift`，补充 `BackupTests.swift`、`HealthExportTests.swift`、原生 `NutritionWorkflowTests.swift`。

组合最多 50 项、至少一项，可添加/修改份量/移除，复制时所有组合与条目 UUID 重建；删除为软删除，旧饮食不变。历史存组合先生成草稿。保存通过修订保护冲突、同一事务添加缺失食品引用；应用组合时建立全新饮食明细，复用既有 `saveWithHealthIntent`。DomainValidation 检查嵌套 ID、顺序、引用、快照与营养计算一致性，不能用损坏备份篡改计算值。沿用本地容量和 50MB 上限。

场景：新建三项→修改→保存→重启→按 0.5/2 份记录并核对每项；快速热量项宏量未知；重复食物独立 ID；历史存草稿/取消不写；同 ID 双击幂等；编辑旧修订失败；归档来源保留组合快照；删除组合不删除饮食；事务注入失败无部分明细/健康任务；原 v1 备份成功导入、v2 导出恢复组合/收藏、错误版本拒绝；恢复不自动重写 Health，完成核对后按既有规则同步；每组件 UUID、修订和未知值行为不变。

- [x] **U4：原创搭配与记录指南（R5；依赖 U1、U3）**

文件：新增 `Core/Nutrition/NutritionContentCatalog.swift`、`Resources/Catalog/nutrition-content.json`、`Features/Nutrition/NutritionContentView.swift`；测试新增 `app/ios/LeanoraTests/NutritionContentTests.swift`，扩展原生 `NutritionWorkflowTests.swift`。

6 套范例使用现有有来源食品和明确克数，标注生熟、原料口径与来源；运行时由同一计算器计算营养，不保存手写总热量。8 篇原创指南讲清份量/生熟与可食部、标签 kJ/kcal、未知营养、常吃组合、来源差异、目标反馈、备份与 Apple Health。MIT 原创文本与 CC0 来源数据分别注明。预览不写；采用进入未保存草稿，后续走 U3。内容全部离线，失败状态可返回日记。

场景：6/8 数量、唯一资源 ID、全部引用可解析、计算与明细相同；无固定个人摄入处方；预览零写入；采用草稿取消零写入；明确保存/记录成功且历史不改；缺失引用或损坏 JSON 关闭该内容入口并解释，不崩溃。

- [x] **U5：日记布局与营养反馈（R6；依赖 U2–U4）**

文件：修改 `Features/Nutrition/DietDiaryView.swift`、`Core/Nutrition/NutritionCalculator.swift`，必要时调整 `Features/Today/TodayView.swift`；测试扩展 `NutritionWorkflowTests.swift`、`NutritionCalculationTests.swift` 与原生 `NutritionBodyTests.swift`。

保留既有日期选择/前后日、四餐添加、快速热量、历史复制和编辑删除；在摘要附近增加组合入口及缺失字段反馈，指南和范例放次级“食物与记录”区。每餐显示条数和已知营养，目标差额保持明确口径。来源说明可展开；大字号纵向回退，固定操作栏避开键盘和列表最后项，VoiceOver 标签包含名称/数量/单位。

场景：空一天非零、只有快记时宏量未知、部分值显示缺失条数、已知零与 nil 区分；前后日目标按生效日期；新增/编辑/删除后首页和日记一致；跨日保存有确认；快速连续关闭/打开无呈现冲突；深色最大字号下组合编辑、份量、保存/取消可用；关键路径不依赖颜色判断。

- [ ] **U6：回归、素材与正式送审（R7、R8；依赖 U1–U5）**

文件：更新 `app/ios/Leanora.xcodeproj/project.pbxproj`、`app/scripts/generate_project.rb`、`app/THIRD_PARTY_NOTICES.md`、README、`app/store/`；新增 `app/docs/nutrition-workflow-1.3.md` 和本轮 `app/docs/qa/` 结果、签名核验、上传与审核回执。扩展 `app/ios/LeanoraUITests/StoreScreenshotTests.swift`。

基础回归涵盖旧训练、备份和 Health 队列；原生验证覆盖收藏搜索→份量→记录→编辑→组合保存→重启→半份记录→日反馈、范例采用与离线指南，以及深色大字号。商店截图仅来自真实隔离数据测试。正式包核验 Release 无测试数据、目录/资源/许可、签名和已有 Health 权限；上传成功后继续确认 Apple VALIDATED、正确版本构建和正式等待审核回执。

既有 1.2（6）刚进入审核队列。先完成并验证 1.3 的全部成果，再按后台实际状态提交；若 Apple 阻止并行版本且需要撤回 1.2，将在最后一步说明具体版本替换影响并取得所需决定。不会为了本轮开发提前撤回上一版或自动发布已批准版本。

## 系统影响与风险处理

- 新数据仍由 `AppModelActor` 写入，所有修改传播到 JournalStore 后刷新日记和首页。未保存组合和内容浏览不产生摄入或健康任务。复制和应用保留快照；编辑目录不会污染历史。
- 新枚举的全部 switch、嵌套容量、备份版本检查需一起更新；SwiftData 仍存同一带校验摘要的业务载荷。新备份不能在旧客户端恢复，界面和文档会说明使用 1.3+；升级前旧备份依然可导入。失败回滚保持原库，不做破坏性降级。
- 最大组合 50 项；搜索在 500 条本地食品中运行，最近从本机明细派生。复用现有容量保护，不声称未测量的性能或专业营养准确率。
- 原始 ZIP 和逐项核验必须来自官方公开文件；没有源记录的不加入数字库。独立中文译名与美国食物分类不冒充中国品牌或餐馆菜肴覆盖。
- 公开仓库排除私人饮食、健康数据、审核电话、认证和完整上传日志。保留开始本轮前已有的 `Localizable.xcstrings` 修改，验证与正式快照不带入该未提交改动。
- 模拟器验证不替代真机 HealthKit、最低 iOS、真实 VoiceOver、锁屏通知或专业营养内容验收；本轮按实际证据记录范围。

## 依据与计划复核

沿用 `NutritionRepository` 的快照与健康意图事务、`TrainingRepository.setExerciseFavorite` 的收藏模式、`BackupService` 的版本/容量/恢复边界、1.2 QA 的列表滚动和固定栏定位经验。仓库没有单独 `docs/solutions/` 或上游 requirements 文档，本轮由用户请求和已有功能合同直接界定。

本计划按一致性、可实现性、产品、交互、安全和反方视角在主线程顺序复核，重点补齐了：基础目录已缓存后的中文升级、快速热量在组合中的未知语义、备份 v1/v2 前后兼容、批量记录的幂等/事务，以及上一版正在审核时的最终发行决策。

外部参考（2026-10-30 核对）：[薄荷官网](https://www.boohee.com/apps/)、[薄荷 App Store 开发者介绍](https://apps.apple.com/cn/app/id457856023)、[USDA 数据许可](https://fdc.nal.usda.gov/api-guide/#licensing)、[Apple 创建新版本](https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version)、[Apple 从审核中移除提交](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/remove-a-submission-from-review)。

## 实施记录

2026-10-30：U1 已完成，500 条食品、209 个中文名、旧 300 条营养和份量指纹一致，500 条全部营养值与官方 ZIP 逐项相符。U2–U5 已完成，基础回归 138 项、0 失败、2 项原有容量测试跳过。三个新增原生流程均通过，包括收藏/历史组合/重启、原创内容取消采用与指南、深色超大字号组合编辑和非法份数；16 个原生用例经定向分批复测通过，全部最终引用均有完整结果包；不是单次全套绿色结果。最终签名导出、资源和权限审计已通过，1859 项应用/工程输入与功能提交逐项匹配；1.3（7）上传成功。正式替换送审等待 Apple 当前队列处理及所需决定，见本轮发行回执。
