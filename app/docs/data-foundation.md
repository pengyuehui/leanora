# U2 数据基础合同

日期：2026-10-20。全部独立实现，无第三方运行时依赖。

## 领域与持久化

`Core/Domain` 是 Codable、Equatable、Sendable 的 Swift 值对象。训练的动作/组、模板条目和食物份量保存为父聚合的一部分；历史动作和营养保留独立快照，不引用可变的目录值。未知营养素为 nil，RPE/RIR 保存原始尺度；标准单位为 kg、m、s、kcal、g，体脂领域值用百分数（Health 写入转换留在 U7）。

`AppModelActor` 是唯一业务写入入口，不向 View 暴露 SwiftData 对象。SwiftData 的 `StoredRecord` 按稳定 key 存储一个类型化聚合及 SHA-256 校验值；业务与设备健康状态分开命名。它不是前期 SQL 的逐表移植。引用、全局/子项 UUID 唯一性、排序、数值、时区归日、同设备一个进行中训练等约束在提交前校验。

本地保存严格递增 revision；同版本相同内容可重试，不同内容拒绝覆盖。删除保存 tombstone；被引用目录条目归档。每次业务操作只执行一次显式 `ModelContext.save()`；任何抛错执行 rollback，关闭自动保存。业务与其健康任务共同提交，任务按业务 ID/组件合并最新版本；旧组件变未知时可排删除任务。游标与外部样本页同事务，查询边界固定。这里不调用 HealthKit 样本 API，不宣称跨 SwiftData/HealthKit 原子提交。

SwiftData 为本地配置 `cloudKitDatabase: .none`。小型偏好由 UserDefaults 缓存；数据库是恢复后的权威来源。后续 U3–U5 添加界面和查询服务；U8 再测最低机型的大数据查询目标，目前不宣称已达到 10 万样本或 p95 性能目标。

## schema 与恢复

磁盘 schema v1 包含 key/kind/payload，v2 添加可空 digest；使用 `Schema(versionedSchema:)` 和显式轻量迁移计划。业务 JSON 格式版本独立为 1，不能随意改枚举 case、字段或单位；将来不兼容更改需新 JSON 版本及迁移。

打开已有数据库之前，保存 SQLite 主文件及 WAL/SHM 的本地恢复代。必须在尚无打开的 container 时调用 `StoreFactory.open`，应用启动符合此约束。成功打开后最多保留最近三代；失败打开不清理旧恢复代，也不删除旧数据库。数据库损坏、文件保护不可读或校验错误显示阻断页面，可解锁后重试或选择恢复时间点。

手工恢复先复制所选完整代，再保留当前文件到 `BeforeRestore-*`，安装副本。`Restore.pending` 在跨文件安装前落盘；如果进程中断，下一次启动拒绝新建空库，用户可再次选择完整副本。恢复失败时尝试回滚；即使 OS 拒绝回滚，原件仍在保留目录。恢复副本是同机升级救援，不能替代用户导出的跨设备 JSON。

数据库、恢复与应用内临时副本设置 iOS `FileProtectionType.complete`，并排除系统自动备份。业务库位于 Application Support，不暴露在 Files。真机锁屏行为需连接 iPhone 验证，模拟器无法证明硬件文件保护。

## 备份格式与合并

JSON 顶层包含 `format=app.leanora.backup`、版本、导出时间、profileID、records。1.3 新导出为 `version=2`，增加组合餐业务类型；继续读取原 `version=1`，但格式 1 不能携带组合餐。旧客户端会拒绝格式 2，需要 1.3 或更高兼容版本恢复。收藏为可选字段，旧数据缺失时未收藏。导出只有业务值，包含稳定 UUID、修订、快照和删除标记；不包含外部健康缓存、HK UUID、同步映射、抑制、游标或任务。文件未加密，系统保存面板由用户选择目的地；界面提前说明敏感性。

读取以 64KiB 分块，最多 50MiB；最多 100,000 条业务对象（包含聚合子项）。预检校验版本、UUID、引用、范围和日期，不执行内容、不访问备份中的 URL。确认前不写库，预览持有本机快照指纹，期间本机变化则拒绝旧预览。

| 同 ID 情况 | 默认行为 |
|---|---|
| 同版本、同内容 | 跳过，幂等 |
| 较旧版本 | 跳过 |
| 较新版本 | 用户勾选采用后更新 |
| 同版本、不同内容 | 显示冲突，保留本机 |
| 同 ID、类型不同 | 拒绝 |

空库（仅自动生成身份）采用备份身份。非空异身份不能自动混合：需系统文件导出成功、当前导出指纹仍一致，再二次确认整库替换。替换不调用 HealthKit 删除。合并后的全集再次验证，任一失败全部回滚。

导入取消旧待写任务、持久化 `reconciliationRequired` 门槛；不同身份替换还清除设备缓存。恢复后的普通保存仍可使用，但排健康任务会被拒绝，直到 U7 的用户重连/映射核对功能解除门槛。不会把备份恢复变成全量重写 Health。

## 验证入口

`PersistenceTests.swift`、`MigrationTests.swift`、`BackupTests.swift` 运行同一份生产代码。迁移 fixture 用 v1 SwiftData 实际写盘，再以 SQLite 一致性备份生成关闭的 fixture，避免 Core Data 延迟 checkpoint 让字节断言失真。故障注入发生在一次提交前，验证完整回滚；损坏库与恢复中断另有磁盘测试。

UI 测试在隔离的 Application Support/LeanoraUITesting、独立偏好域中运行。测试文件仅由 Debug 且 `--uitesting --backup-fixtures` 同时存在时生成；Release 不包含这些标记和内容。普通运行不自动生成业务示例。
