# 阶段 2 / U2 验证

日期：2026-10-20。范围：领域值对象、SwiftData 显式事务、迁移恢复、版本化 JSON 导入导出及设置入口。**最终 47 项原生测试全部通过：31 项单元、16 项 UI/原生权限；0 失败、0 跳过、0 运行时告警。Release 编译通过。**

## 测试环境与产物

- Xcode 27.1、Swift 6、最低 iOS 18；iPhone Duo / iOS 27.1 模拟器。
- 最终设备：`71FE8650-F7DF-4608-84A5-01689F7A8110`（Leanora U2 Final）。
- SwiftPM：`app/build/u2-swiftpm-final.log`，31 项通过。
- 原生最终结果：`app/build/U2FinalVerified.xcresult`、`app/build/u2-final-verified.log`。
- 原始摘要：[phase-two-results.json](phase-two-results.json)；测试时间 17:45–17:50（Asia/Shanghai），约 313 秒。
- Release：`app/build/U2Release`、`app/build/u2-release.log`，iPhone Release 编译通过，不含测试适配器。
- Release 7 个 Debug 标记/夹具扫描均为 false，隐私清单解析通过：[发布构建检查](phase-two-release-audit.json)。
- 初轮失败/定位结果单独保留在 build，不作为最终通过证据。

## U2 验收映射

| 合同 | 实际验证 |
|---|---|
| 离线数据重开可见 | 真实磁盘写入、重新创建 container；全部业务与子项 ID、快照指纹相同；UI 导入后强退重开 |
| 业务与健康队列原子提交 | 新增/编辑注入提交失败后，业务和任务共同回滚；重试只保留最新任务 |
| 导入页与游标原子提交 | 批次失败不新增样本或前进游标；删除页失败保留旧批次，成功后一起前进 |
| 历史不随目录变化 | 修改/归档动作、修改模板和食物后，已存训练与餐食快照不变 |
| 原始努力尺度与未知营养 | RIR 保留原值；未知营养仍 nil；已知蛋白质改未知后排删除任务，绝不写 0 |
| 身体与目标历史 | 一天两次测量均保留；修改当前目标保留过去的目标 |
| v1→v2 迁移 | 实际 v1 SQLite fixture，显式版本迁移至 v2，业务/子项 ID 与快照等价 |
| 迁移/打开失败 | 失败注入保留原字节及恢复代；真实损坏 SQLite 被拒绝，原文件不被替换为空库 |
| 恢复中断 | 存在 Restore.pending 时禁止创建空库；选完整副本后可重新打开原业务 |
| JSON 往返及幂等 | 原生保存/文件选择与导入；相同备份再次导入不新增；同身份修订和冲突规则 |
| 身份隔离 | 空库采用备份 UUID；非空异身份先导出当前指纹，再明确整库替换 |
| 预览过期 | 预览后本机保存新记录，旧预览被拒绝 |
| 不可信文件 | 坏 JSON、未知版本、坏 UUID、断引用、数值/日期错误、无来源体积换算被拒绝 |
| 有界读取 | 超过 50MiB 的内存数据/磁盘文件在解码前被拒绝；10 万条限制包含子项 |
| 导入失败原库完整 | 事务故障后业务指纹与设备健康状态均不变；预检失败不写库 |
| Health 不全量重写 | 导出不含缓存、链接/HK UUID、游标、队列、抑制；导入不造任务并持久化核对门槛 |
| 本机隐私 | 数据库/恢复副本的 isExcludedFromBackup 属性通过；iOS 设置 complete 文件保护 |
| 页面与基础回归 | 数据管理错误/预览/结果、真实导出/选择/取消、启动失败重试、最大字体深色；U1 全导航/偏好/原生权限回归 |

## 处理过的问题

1. Core Data 保存后的异步 checkpoint 会改变测试源库物理布局；迁移 fixture 改用 SQLite 一致性 backup API 生成关闭副本，字节与逻辑内容均可验证。
2. iOS 27.1 Duo 的文件名和工具栏具有独立实际触点。XCTest 改为点击文件缩略图及保存按钮中心，真实保存和导入成功。
3. 最大字体下导出按钮在屏幕外；测试先滚动到可触达入口。页面本身保持可滚动。
4. 审查补充跨文件恢复的持久化中断标记，避免恢复中断后初始化空库。

## 实际限制

没有连接物理 iPhone。模拟器不返回硬件文件保护属性，不能证明锁屏时不可读、设备解锁后的恢复或真实 VoiceOver 行为；这些与 U1 最低系统/真机门槛继续保留。原生系统权限在模拟器验证，不代表已完成 U6/U7 的真实样本同步。

此阶段交付数据基础与 JSON。动作/模板页面、训练过程、饮食/身体录入、趋势、Health 样本读写、CSV、清除本地及单独删除 Health 副本按 U3–U8 实施。尚未宣称达到 U8 的最低机型大数据性能目标，也没有 TestFlight 发布。

## 最终截图

[数据管理](phase-two-screenshots/u2-data-management.png) · [系统保存面板](phase-two-screenshots/u2-export-file-panel.png) · [导入预览](phase-two-screenshots/u2-import-preview.png) · [导入结果](phase-two-screenshots/u2-import-complete.png) · [无效文件](phase-two-screenshots/u2-invalid-backup.png) · [启动失败](phase-two-screenshots/u2-store-open-failure.png) · [最大字体深色](phase-two-screenshots/u2-data-large-dark.png)。已逐项检查预览及最大字体截图，按钮可达、文字随字体换行，无横向截断。
