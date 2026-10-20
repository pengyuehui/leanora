# 阶段 3 / U3 验证

2026-10-20。范围：R4 / U3 动作库、模板、周安排、单次改期与开始训练。**最终完整原生验收 69 项全部通过（46 项单元、23 项 UI/原生权限），0 失败、0 跳过、0 运行时告警；最终 iPhone Release 构建通过。**

## 环境和产物

- Xcode 27.1、Swift 6、iOS 18 最低目标；iPhone Duo / iOS 27.1 模拟器。
- 最终设备：`C7E5E80A-8BB8-4A54-B93E-C18057CE452F`（Leanora U3 Verified）。
- SwiftPM 同源生产数据代码：`app/build/u3-unit-final.log`。
- SwiftPM 46 项全部通过；新增 TrainingPlanTests 15 项、TemplateEditorTests 7 项，原有测试全部回归。
- 最终完整原生回归：`app/build/U3Verified.xcresult`、`app/build/u3-verified.log`。
- 原始结构化结果：[phase-three-results.json](phase-three-results.json)，整轮约 9 分钟。
- 初轮失败定位（不作为通过证据）：`app/build/u3-final-verified.log`。两项测试稳定性问题修正后，重跑完整回归。
- 最终 Release：`app/build/U3Release`、`app/build/u3-release-final.log`；资源/Debug 隔离检查：[phase-three-release-audit.json](phase-three-release-audit.json)。

## U3 验收对应

| 功能 | 验证 |
|---|---|
| 离线基础动作 | 真正打包/加载 22 条条目，UUID 唯一、来源完整；不依赖联网、不导入第三方素材 |
| 搜索与组合筛选 | 中英文别名、大小写、肌群/器械组合、空结果、归档排除；原生搜索和器械选择 |
| 自定义/归档/来源 | 原生新建及归档，来源展示；服务层改名/归档/恢复后引用和历史快照保持 |
| 新建/编辑模板 | 动作依赖与模板原子保存；失败没有半条业务；过期 revision 不覆盖新版本 |
| 目标与单位 | 组数、次数范围、负重、时间、距离、休息；kg/lb、m/km/mi 转换；错误文本拒绝，未知值为空 |
| 重复项目与重排 | 同一动作两个项目独立 UUID、顺序及目标；实际原生编辑目标、下移并重新打开 |
| 模板复制 | 新父/子/关联 ID，不复制周安排；原生复制和重启后可见 |
| 空模板保护 | 服务层拒绝开始；原生开始按钮禁用，说明可见 |
| 每周安排 | ISO 周日期持久化；当天安排可见，未来日期开始按钮禁用 |
| 单次改期 | 从原日移至目标日，下周不变，移回原日不重复；原生改到明天，重启仍保留 |
| 改期与开始隔离 | 改期不创建 session，已开始来源安排禁止改期；修复同一 List 行多按钮联动并复测 |
| 开始与恢复 | 开始当天安排，实际组不自动完成；并发开始同 ID；原生关闭/强退重开可返回并放弃 |
| 历史快照 | 改模板/动作/归档/删除模板后，已开始 session 不变；模板目标与实际值分离 |
| 资源边界 | 开始前拒绝会展开超过对象上限的大模板，库无新增半条 session |
| 时间变化 | 恢复未来开始时刻/系统回拨后可放弃，持久化结束不早于开始 |
| 备份/迁移回归 | 新 schedule 和 optional 快照字段磁盘重开/JSON 往返，原有 v1→v2 fixture 回归；不排 Health 任务 |
| 页面可用性 | 搜索、错误、确认、数字/文本键盘收起、最大字体深色和原生导航；旧偏好/权限/备份回归 |

## 发现与修复

1. 搜索默认折叠：明确 navigationBarDrawer 展示，测试兼容系统搜索按钮。
2. 模板名称键盘在动作选择返回后恢复：添加明确 Done，并在打开选择器前取消焦点。
3. List 默认样式让同一行两个操作一起响应：改为 borderless，各自执行开始或改期。
4. 归档确认的系统控件有父子两层同 ID：测试选定实际首个控件；不重复提交归档。
5. 组展开先校验数量，避免大量计划先分配再因库限制失败；删除和未来时间恢复有额外测试。
6. JSON 毫秒编码往返与原 Date 可能相差浮点精度：断言以同一持久化 session 的开始/结束顺序为准，并验证原始时间误差小于 1ms。
7. 模拟器系统文件保存面板初始化时首次触点偶发未激活：测试等待实际结果并对仍可操作的面板进行有界重试。

## 保留范围

没有物理 iPhone；最低系统真机、真实 VoiceOver、硬件锁屏保护仍按 U1/U8 设备门槛保留。模拟器系统授权不代表 Health 样本同步已交付。22 条目录只做本轮开发自检，专业内容复核和首版约 100 条目标另有发布门槛。

当前可保存计划并开始/返回训练，逐组执行、暂停/计时、完成与统计在 U4；饮食/身体/趋势在 U5，Health 样本读写在 U6/U7。没有 TestFlight 发布或商业签名验证，不宣称最低机型大数据性能通过。

## 最终截图

[动作来源](phase-three-screenshots/u3-exercise-source.png) · [自定义归档](phase-three-screenshots/u3-custom-archived.png) · [重排](phase-three-screenshots/u3-template-reordered.png) · [模板重启保存](phase-three-screenshots/u3-templates-persisted.png) · [空模板保护](phase-three-screenshots/u3-empty-template.png) · [单次改期](phase-three-screenshots/u3-one-off-move.png) · [训练已开始](phase-three-screenshots/u3-started-workout.png) · [最大字体深色](phase-three-screenshots/u3-library-large-dark.png)。已检查来源、改期、训练快照和大字体截图；主信息可读、按钮可达。大字体搜索文字由系统搜索控件滚动/截显。

训练区域改动前参见 [U1 训练空状态](screenshots/iphone-tab-training.png)，改动后参见模板保存截图。
