---
status: complete
priority: p1
issue_id: "005"
tags: [ios, healthkit, release, ux]
dependencies: ["004"]
---

## Problem Statement
完成原计划 U6–U8 的实现及可执行验证，按训记的记录主流程改进原创界面。

## Findings
开始时 U1–U5 已提交，Health 仅授权，CSV、分离清理和发布资料尚缺。本条现已完成源码及本机验证；真机/签名账号仍是外部发布验收条件。

## Proposed Solutions
串行实施可测试的同步合同、真实 HealthKit 适配器、同步与清理界面，再调整首页/训练/饮食操作密度。

## Recommended Action
沿用已授权功能分支独立实现，保留原始验证证据，用户指定格式提交。

## Acceptance Criteria
- [x] U6：有界分页、原子游标、观察重试、来源与活动统计
- [x] U7：稳定版本、逐组件队列、抑制、恢复核对、停止同步
- [x] U8：CSV、分离清理、隐私与发布材料、容量/恢复验证
- [x] 原创布局与训练/饮食主流程优化，原生界面验证
- [x] 完成源码审查、构建和适当测试；真实设备/签名门槛据实记录
- [x] 按规定格式提交

## Work Log
2026-10-21：核对剩余计划、数据合同、原生工程与官方 HealthKit 资料，开始实施。
2026-10-21：完成 U6–U8 本机源码及原创页面调整；134 个独立测试方法按最新非跳过结果通过，含容量与真实系统 Health 体重写入确认。最终 Release Archive 构建并审计通过。主线程顺序审查见 ce-review/20261021-u678/review.md。提交使用用户指定模板。本条完成不代表物理设备或 TestFlight 门槛通过，后续按 app/docs/release-checklist.md 执行。
