---
status: complete
priority: p1
issue_id: "002"
tags: [ios, stage-two, persistence, backup]
dependencies: []
---

# 阶段 2：领域、事务、迁移与备份

## Problem Statement
按用户授权完整实现开发计划 U2，验证离线保存、原子提交、版本迁移和安全备份往返。

## Findings
U1 工程和模拟器验证可用；真机门槛仍独立保留。SwiftData 不开启 CloudKit；恢复不可自动排出健康写入。

## Proposed Solutions
原生 Codable 领域值对象与 SwiftData 持久化 actor；显式保存/回滚；版本化 schema 与受保护恢复副本；有预检和确认的 JSON 导入导出。

## Recommended Action
实现 U2 与可操作的数据管理入口，执行磁盘重开、故障注入、迁移 fixture、导入安全和 UI 验证，再做顺序代码审查。

## Acceptance Criteria
- [x] 业务模型、历史快照、单位/日期/来源/修订和删除标记完整
- [x] 业务与健康队列、导入批次与游标各自原子提交，失败回滚
- [x] v1→v2 磁盘 fixture 迁移保留 ID；失败保留可恢复原库
- [x] 备份排除设备健康状态；往返、幂等、冲突和身份规则通过
- [x] 50MB/10万条限制、引用/数值/格式预检、失败原库不变
- [x] 数据管理页面、构建、单元及 UI 验证完成并记录限制

## Work Log
### 2026-10-20
用户明确授权阶段 2。保留 U1 真机待验收状态，继续独立数据基础实现。

最终完整原生验收 47 项通过（31 单元 + 16 UI/原生权限），0 失败/跳过/运行时告警；SwiftPM 31 项通过；Release 构建和 Debug 隔离检查通过。按 AGENTS 在主线程顺序审查，已补恢复中断保护、组件删除和导入核对门槛。证据见 app/docs/qa/phase-two-verification.md；真机文件保护/VoiceOver/最低系统门槛仍独立保留。
