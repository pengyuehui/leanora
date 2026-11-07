# 历史、动作与 Health 专项验证

2026-11-07：完成源码实现与原生验证，迭代标记为 1.5；测试 App 仍为 1.4（8），没有提升发行版本号、上传或重新提交 App Store。原有工程文件、Info.plist 和字符串目录的未提交改动逐字节保留并排除本次提交。

- 核心：154 项，152 通过、2 项既有容量测试按配置跳过，0 失败。新增月历闰年/DST/七列、肌群分类、暂停范围恢复和授权诊断回归。
- 原生单元：4 项 HealthCoordinatorTests 通过，包含授权取消、配置保存失败、新记录写出、停止与副本删除边界。
- 原生 UI：10 个不同用例分批最终通过。第 4 批 6 项全部通过，包含历史月历/分类/统计、动作搜索/器械/收藏/指导/训练入口、Health 首次自动请求失败与暂停重启、大字体深色、复制取消/选择餐次/提交/重启。第 2 批完整训练与饮食工作流通过。第 1 批的真实系统 Health 授权/写入用例通过；第 5 批补跑最终星期标题的大字体布局，第 6 批补跑零写入权限不误报同步的语义，各 1 项通过。
- 真实 HealthKit：全新独立模拟器出现 Apple 系统访问页，选择允许写入及受限历史后保存 65.4 kg 测试记录，原生 transport 查回同源样本建立关联；手动重试后仍为一个关联组件。不是仅凭 App 内的“完成请求”文字判断写入成功。
- 视觉：检查普通历史/动作图片库/分类统计，以及 AX XXXL 深色的纵向今日卡、完整七列月历和单列动作卡。早期横向布局及固定侧栏在大字体下拥挤，已经替换，旧截图不作为最终视觉证据。
- 审查：correctness 和 adversarial 在主线程顺序执行，结果见 [review.json](review.json)。未改业务 schema、Health 数据所有权、旧记录导出门槛或第三方内容许可。

第 1 批曾主动中断，包含测试定位失败；第 2 批 5 过 1 失败，第 3 批 4 过 2 失败。剩余失败来自重名 Tab/筛选按钮和系统组合标签定位，修正后第 4 批 6 项全过。不能将分批通过描述为一次全量测试全绿。详细用例、时长、日志哈希及截图来源见 [verification.json](verification.json) 与 [screenshots.json](screenshots.json)。

环境：Xcode 27.2（27B52）、iOS 27.2（24B8117）、独立 iPhone 17 Pro「Leanora 1.5 QA」。UI 图中记录均为测试夹具；原有模拟器和用户业务数据未清除。构建关闭 Swift 自动字符串提取，防止改写用户现有字符串目录。

## Health 故障边界

源码确认首次打开自动同步绕过系统授权，以及暂停后未恢复范围两处问题，均已修正。现在顶部连接按钮和自动开关走同一个授权 → 保存 → 同步入口，失败给出 domain/code，不将原先关闭的同步显示为开启。已处理过的范围可能不再弹窗；系统不披露读取授权，完成请求不代表全部允许，详见[健康合同](../../health-sync.md)。

用户报告“无法弹出系统授权，或提示请求失败”，没有提供原设备具体错误码。本次没有在用户物理 iPhone 复现，不能认定两处源码问题为原设备的唯一原因。真机权限、锁屏/后台投递、最低 iOS 18 和真实 VoiceOver 仍是独立验收范围。安装新构建后若仍失败，可用页面显示的 NSError domain/code 继续定位。

## 重现与证据

```sh
swift test --package-path app
xcodebuild -project app/ios/Leanora.xcodeproj -scheme Leanora \
  -destination 'platform=iOS Simulator,id=8BF77AA8-EFF5-4F00-BA17-55E7E842C5FC' \
  -derivedDataPath app/build/V15Derived SWIFT_EMIT_LOC_STRINGS=NO build-for-testing
xcodebuild -project app/ios/Leanora.xcodeproj -scheme Leanora \
  -destination 'platform=iOS Simulator,id=8BF77AA8-EFF5-4F00-BA17-55E7E842C5FC' \
  -derivedDataPath app/build/V15Derived -parallel-testing-enabled NO \
  -only-testing:LeanoraUITests/HistoryActionsTests \
  -only-testing:LeanoraUITests/ReviewWorkflowTests/testCopyDayPreviewCancelCommitAndRelaunch \
  test-without-building
```

原始日志与 XCResult 位于忽略的 `app/build/v15-*` 和 `app/build/V15-20261107-*.xcresult`，哈希记录在验证文件中。真实系统权限用例使用 `--system-permissions`；故障和暂停用例使用可控 authorizer，二者分别记录。

普通[历史](v15-history-today-calendar.png)、[动作](v15-exercise-library.png)、[体重统计](v15-body-statistics.png)；大字体深色[今天](v15-history-large-dark.png)、[月历](v15-calendar-large-dark.png)、[动作](v15-exercises-large-dark.png)；系统[授权](u678-system-health-before-allow.png)、[受限历史](u678-system-health-limited-history.png)、[写回](u678-system-health-write-echo.png)；[错误恢复](v15-health-authorization-error.png)。

交互合同：[历史与动作](../../history-actions-1.5.md)。实施计划：[2026-11-07 计划](../../../../docs/plans/2026-11-07-001-fix-health-history-actions-plan.md)。
