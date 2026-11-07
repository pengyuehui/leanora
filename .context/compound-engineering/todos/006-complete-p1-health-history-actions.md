---
status: complete
priority: p1
issue_id: "006"
tags: [ios, healthkit, navigation, design]
dependencies: []
---

## Problem Statement

用户报告 Apple Health 仍不可用，并要求合并今天/趋势、月历历史页、动作分类图示页和精简文案。

## Findings

Health 自动同步开关绕过授权请求；关闭后页面不恢复既有读写选择。今天和趋势入口分散，动作库在训练次级页面。原始三个工程/资源改动存在，需保留。

## Proposed Solutions

沿用现有存储和同步队列，修正授权入口与反馈；四 Tab 导航、今日概览+历史月历/统计、动作侧栏与图片网格。方案见 docs/plans/2026-11-07-001-fix-health-history-actions-plan.md。

## Recommended Action

按用户已授权要求直接开发，主线程顺序实施、审查和验证。

## Acceptance Criteria

- [x] Health 授权、暂停恢复及错误路径有回归证据
- [x] 今日置顶的历史月历与统计可操作
- [x] 动作侧栏/搜索/器械/收藏可用，训练和模板仍可达
- [x] 主流程文案精简，必要来源与权限说明保留
- [x] 核心与原生关键回归、截图和提交完成

## Work Log

- 2026-11-07：开始源码定位，保留原有未提交文件；已请求真机症状以便核对。
- 2026-11-07：实现四 Tab、今日置顶/月历/统计、动作侧栏图片库，修复授权入口和暂停范围；核心 152 通过/2 跳过，原生单元 4 过、不同 UI 用例 10 过，最终批次 6/6。用户确认症状为未弹授权或请求失败；新模拟器原生授权和体重写回通过，原设备错误仍待新构建真机复测。QA 证据在 app/docs/qa/history-actions-health-20261107，按既定格式保存源码提交。
