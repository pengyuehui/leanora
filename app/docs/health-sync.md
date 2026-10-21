# Apple Health 同步合同与实现

更新：2026-10-21，Leanora 0.2。运行时只使用 Apple SDK，无服务端。

## 入口与方向

「我的 → Apple Health」选择身体、训练、营养的读取/写入和只读日常活动，然后完成系统请求。自动同步可随时关闭。首次连接从最近 90 天开始；若系统另行限制历史访问（本机 SDK 显示 30 天/完整历史选择），实际结果遵守该系统范围；扩大授权时使用新的导入代次重扫。连接不会自动导出旧记录。「同步状态与健康摘要」显示最近检查、逐组件待处理/失败、读取范围、来源与外部只读数据。

授权请求完成不是读取或全部写入获准的证明。空结果显示“暂未读到数据，可检查健康访问或手动记录”。HealthKit 不能可靠区分拒绝读取与空库；每个写入组件单独检查 sharingAuthorized。

## 读取

`HealthImportService` 按类型串行请求 500 条 anchored page。固定起点和安全归档的 anchor 在 `AppModelActor.commitHealthImport` 中与样本及删除一起提交；失败不推进。重新授权使用新 generation，样本 UUID 保证重复导入幂等。未关联的本 App 历史样本也作为外部摘要保留。

只有本 App 来源、稳定 sync identifier 与本机业务对象同时匹配时才排除回声。外部营养素独立保留，不按同一时间捏造餐别/食物名。关闭读取不继续拉取；清除缓存先停止同步，不删除原始健康样本。缓存页面每次 100 条，不在主线程一次性解码十万样本。

`HealthObserverCoordinator` 注册所选类型，通知进入同一 engine。查询超时 25 秒；检查开始前持久化 retryNeeded，失败保留缓存/游标，前台或手动重试继续。完成回调一次结束。后台频率及锁屏投递由系统安排，模拟器不能证明物理后台行为。

每日步数/活动能量用 HealthKit cumulative statistics 结果，不累加各来源原始样本，不与训练能量相加。日边界使用指定 Calendar/时区，显示时区。首版不计算训练心率、能量或未经证实的距离。

## 写入与版本

本机记录和期望任务先原子落库。自动同步仅为启用的组件排队，任务键为业务 UUID + component，新修改合并到最新业务 revision。已开始任务的确认不会删掉期间新生成的任务。

每个组件稳定标识 `app.leanora.<business-uuid>.<component>`，版本为业务 revision 与已观察版本下限的较大值。准备任务时持久化选定版本；崩溃重试仍用同一版本。真实写入前查本来源同标识样本，已有相等/更新版本时恢复真实 UUID。HealthKit 的 sync identifier/version 规则负责同源替换；不使用时间戳生成版本。

热量 kcal，营养素 g，体重 kg，体脂从本机 0–100% 转换为 Health 的比例。未知字段不写 0；已知变未知删除原组件，包括可能在上次成功写入但本机确认失败的组件。已完成训练通过 HKWorkoutBuilder 保存，暂停/恢复作为事件，混合训练为 other。无实际来源的消耗与距离保持空值。

来自 Health 的当前副本删除会抑制该组件自动补写；旧版本替换删除不会抑制新版本。本机记录保留。外部只读摘要可以隐藏，历史导出不解除其他来源的隐藏标记。

## 删除与恢复

每条记录删除提供“确认删除”（只删本机）与“同时删除健康副本”。后者是明确手动任务，即使自动同步停止也可单独重试；只按本来源 + 稳定标识删除。全局清理只选择 HKSource.default()，不接触其他 App 的 Health 样本。

恢复备份删除旧任务，保留待核对门槛，恢复记录有独立导出 hold。核对同标识样本重建映射和版本下限，但不排队。只有用户确认“重新导出本机历史记录”才解除 hold/自身删除抑制，明确提示会采用本机版本。系统不披露读取拒绝，空核对不能证明 Health 无记录；实际 SDK 同步版本仍阻止较旧版本覆盖较新样本。未获得可读数据时，用户应先在健康 App 检查访问及版本。

停止自动同步取消未开始的自动任务，保留已经写入的历史副本。已开始写入可能完成，清理操作先等本次写入结束。业务重置创建新身份并保持 Health 写入暂停，不把健康缓存当成业务备份。

## 统计边界

来源页对时段重叠的记录显示可能重复提示，允许关联并选择本机/健康主记录，关联摘要时长只取一个来源。

本机训练统计只含本机已完成业务记录；健康来源在单独的摘要区展示，不合计到本机训练容量/时长。时段重叠可提示用户，但不会悄悄删除来源、把手表能量与本机训练重复相加。逐组明细、模板与完整餐次以 JSON 备份为准，Health 不能还原这些数据。

## 官方依据

- [授权与读取隐私](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [Anchored queries](https://developer.apple.com/documentation/healthkit/executing-anchored-object-queries)
- [Sync identifier 与替换规则](https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncidentifier)
- [统计集合查询](https://developer.apple.com/documentation/healthkit/executing-statistics-collection-queries)
- [保护健康数据隐私](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)
