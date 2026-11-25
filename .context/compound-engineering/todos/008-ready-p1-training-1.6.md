---
status: ready
priority: p1
issue_id: "008"
tags: [ios, workout, health, v1.6]
dependencies: []
---

## Problem Statement

执行 2026-11-25 计划中的 1.6：Health 诊断与真机验收、行内逐组录入和撤销、休息暂停恢复、训练中动作替换、回归与发行资料准备。

## Findings

基线 e9203f6；工程、Info.plist、Localizable.xcstrings 有既有改动，已复制到忽略的 app/build/v16-preserved-20261125。当前只发现模拟器，已请求用户连接故障 iPhone。

## Proposed Solutions

沿用现有 SwiftUI / Codable 聚合 / SwiftData 仓库；保存一次完成组的输入与状态；休息 deadline 和暂停剩余秒数持久化；动作替换保留完成组。Health 以无样本值的诊断和发行签名核查补证据。

## Recommended Action

按用户授权直接实施 1.6；串行主线程完成；不实施 1.7/1.8，不自动送审。

## Acceptance Criteria

- [x] Health 请求/同步状态诊断、发行包合同检查和授权回归。
- [ ] 原 iPhone 复现/验证；若设备不可用，明确保留真机验收项。
- [x] 行内输入、下一项/上一项/收起、原子完成、连续点击、失败重试与撤销。
- [x] 显式沿用及可选仅空白自动带入，计量/同动作项目不串值。
- [x] 暂停/继续休息倒计时，提醒取消/恢复，超级组一轮一次。
- [x] 替换筛选/预览/取消/确认、完成组归属、目标清空和保存原子性。
- [x] 核心、集成及原生 UI 回归、视觉检查、旧备份兼容。
- [x] 审查、真实验证报告、截图与发行说明；既有用户改动保留。
- [ ] 恢复 Xcode 发行账号，导出 App Store IPA 并验证 TestFlight（当前 No Accounts / 缺少发行证书）。

## Work Log

- 2026-11-25：开始实施；保存基线文件；读取现有控制器、仓库、Health 和训练流程；已确认模拟器可用、未连接物理 iPhone。
- 2026-11-26：1.6 源码完成；176 项核心测试（174 过、2 跳过）、9 项原生 Health 单元、10 个不同 UI 用例分批通过。完成真实系统 Health 写回、签名 RC2 Archive、七页源截图和 14 张组合图。真机与 TestFlight 验收保留为待办，未上传/送审。
