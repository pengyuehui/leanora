---
status: ready
priority: p1
issue_id: "001"
tags: [ios, stage-one]
dependencies: []
---

# 阶段 1：原生工程、首次使用与权限入口

## Problem Statement
按已批准计划 U1 实现可运行的 iPhone 工程和原创交互基础，并验证功能。

## Findings
工作区无 App 工程；Xcode 27.1 与 xcodeproj gem 已安装。CoreSimulator 访问需正常本机权限。

## Proposed Solutions
使用原生 SwiftUI 和系统 SDK，独立实现。工程用本机 xcodeproj 生成，不引入运行时依赖。

## Recommended Action
实现 U1，构建、自动化测试与截图检查；真实设备/签名未验证时明确标注。

## Acceptance Criteria
- [x] 五个 Tab 与首次使用流程可操作
- [x] 单位、可选目标保存并可修改
- [x] HealthKit/通知真实授权入口及不可用/拒绝/错误替代路径
- [x] 工程、权限配置、原创内容与范围文档完整
- [x] 构建、单元与 UI 自动化测试通过；截图检查
- [ ] 按原计划完成物理 iPhone、VoiceOver 和最低系统运行验收

## Work Log
### 2026-10-20
用户授权阶段 1 全部实现和验证。按 U1 范围执行，不实现 U2–U8。

已完成独立原生工程、原创资源、首次使用、五个 Tab、偏好持久化和真实授权适配。19 项测试通过，包含真实系统 Health/通知拒绝后继续使用；修复数字键盘收起、工具栏重复与布局告警，完成针对性回归。最终结果、截图与设备限制记录在 `app/docs/qa/phase-one-verification.md`。

本机存在开发签名身份，但工程未选择团队，也没有连接物理 iPhone。保留 ready，直到原计划要求的真机门槛验收完成；不把模拟器通过等同于真机通过。
