---
status: ready
priority: p1
issue_id: "007"
tags: [ios, release, app-store]
dependencies: []
---

## Problem Statement
用户要求将已验证的历史/动作重构与 Health 修复提交 App Store 审核。

## Acceptance Criteria
- [x] 1.5（9）版本、真实新截图和中英文资料核对
- [ ] 源码提交与不可变快照一致，发行 Archive/IPA 签名及 HealthKit/资源审计通过
- [ ] Apple 完成二进制处理并选择正确构建
- [ ] 正式提交并保存审核状态回执；保留既有免费/销售范围/手动发布选择

## Work Log
- 2026-11-08：用户已明确授权送审。Apple 登录恢复，当前 1.4 可分发，创建 1.5 草稿；Xcode Manyao Li 团队账号存在。保护原有三个未提交工程/资源改动，只提交版本号增量。
- 2026-11-08：签名 Archive 成功，1905 个输入哈希与 fe88be6 一致，Release 无测试标记。截图采集 1 项通过，14 张导出校验通过，中英文门户逐字核对。CLI 导出 No Accounts，Mac 仍锁定；扩展直传权限不足，保持系统选择器回退。等待已发送的解锁请求，未声称上传/送审完成。
