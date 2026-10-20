---
status: complete
priority: p1
issue_id: "004"
tags: [ios, workout, nutrition, verification]
dependencies: ["002", "003"]
---

## Problem Statement
按已批准计划完成 U4 训练执行/恢复/历史/统计，以及 U5 离线饮食/身体/趋势，并提交所有成果。

## Findings
现有 U1–U3 基线 46 项 SwiftPM 测试通过，原生 69 项通过证据已保留；根仓库已建立。研究代码不进入产品。

## Proposed Solutions
扩展现有值对象与持久化 actor，纯函数计算计时与摘要；本地系统通知；来源清晰的 USDA 离线目录；原生表单与 Charts。

## Recommended Action
按用户授权直接实施、测试、自审与修复后提交，不提前接入 U6/U7 HealthKit 样本读写。

## Acceptance Criteria
- [x] 训练逐组编辑、暂停恢复、独立计时与休息、超级组、完成/放弃和历史统计
- [x] 离线食物搜索、自定义、单位、快捷热量、餐次复制与历史快照
- [x] 身体多次测量、历史目标、今日与周月趋势
- [x] SwiftPM、原生 UI、Release 构建及证据通过
- [x] 按要求格式提交基线与新功能

## Work Log
2026-10-20：确认范围并保存基线 df8e515，开始实现。

2026-10-20：U4/U5 本地功能完成，顺序自审修复；76 项单元、29 项 UI 和独立真实通知排程 1 项取得最新通过结果。完整回归/失败与复测原始 JSON、16 张截图及 Release 审计已保存。基线 df8e515、REA 清单 714da73、本文件及本次功能一起提交。物理设备与内容专业审核仍按主计划保留，不将其算作自动化完成。
