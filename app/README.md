# Leanora

原生 iPhone 训练与饮食日记，独立实现并按 [MIT 许可证](../LICENSE) 开源；第三方内容按[各自许可](THIRD_PARTY_NOTICES.md)保留。已实现 U1–U8 的本机功能：本地事务与恢复、JSON/CSV、882 动作与 300 食品、离线动作图示、模板/周计划、逐组训练/计时/历史、饮食与身体趋势、Apple Health 读写/队列/恢复核对、分离清理。界面按记录主流程重新组织。真机健康、最低系统、内容专业复核与 TestFlight 安装是独立发布门槛，当前不宣称已发布。

2026-10-26 发布更新：**1.1（5）已正式提交 App Store，Apple 显示“等待审核”，审核后手动发布。** 原 100 个条目的 ID 与字段保留，扩充至 882 个动作，全部配有离线指导图，共 1765 张独立图片。284 个名称含中文，原 100 个动作提供中文提示，其余保留来源英文步骤。支持在动作详情、选择动作时和训练中查看、切换及放大图示。来源和重建方法见[动作库说明](docs/exercise-library-expansion.md)，签名、上传及正式送审凭据见 [1.1 送审记录](docs/qa/appstore-submission-1.1.md)。

## 打开与运行

打开 `ios/Leanora.xcodeproj`，选择共享 Scheme **Leanora**。最低 iOS 18，Swift 6；本次构建工具为 Xcode 27.1。没有第三方运行时依赖。

- 模拟器：先在 Xcode Settings → Components 安装 iOS Runtime，然后选择可用 iPhone 模拟器运行。
- 真机：工程已配置 Manyao Li（Team ID `8ZP3NMT2A8`）及正式 Bundle ID `ai.leanora.fitness`，需匹配的 HealthKit 描述文件与已开启开发者模式的 iPhone。
- 2026-10-21：用户要求正式 App Store 提交，工程版本更新为 1.0（3），包含新版图标的开发签名 Archive 成功。发行导出返回 No Accounts / 缺少 iOS Distribution，Mac 当前锁定且商店会话失效；尚未正式上传或送审。见 [1.0 提交准备](docs/qa/appstore-submission-1.0.md)。
- 2026-10-21：正式签名 Archive 与发行 IPA 导出通过，运营主体及支持方式已补齐。商店记录 `Leanora Fitness`（`6825234654`）创建成功，0.2.0（2）内部 TestFlight 上传成功；接收时 Apple 状态为 `PROCESSING`，可安装状态和真机验收仍待确认。公开政策网址仍待可访问性核验。代码不包含签名私钥或账号凭据，见 [发布候选记录](docs/qa/release-submission.md)。

## 验证

商店图标、7 张真实页面展示图、中英文介绍和可交互预览见 [商店素材包](store/README.md)。新版图标和扩展动作库已包含在 1.1（5）发行构建中，正式发行包逐图哈希、完整署名、签名及 HealthKit 权限核验通过；Apple 二进制验证及送审凭据见 [1.1 送审记录](docs/qa/appstore-submission-1.1.md)。

不依赖 iOS Runtime，测试同一份生产基础服务：

```sh
swift test --package-path app --scratch-path app/build/SwiftPM --disable-swift-testing
```

从工作区根目录编译 App 和测试：

```sh
xcodebuild -project app/ios/Leanora.xcodeproj -scheme Leanora \
  -sdk iphonesimulator -configuration Debug \
  -derivedDataPath app/build/DerivedData CODE_SIGNING_ALLOWED=NO build-for-testing
```

安装 Runtime 后，以 `xcrun simctl list devices available` 返回的设备 UUID 运行：

```sh
xcodebuild -project app/ios/Leanora.xcodeproj -scheme Leanora \
  -destination 'platform=iOS Simulator,id=<设备 UUID>' \
  -derivedDataPath app/build/DerivedData \
  -resultBundlePath app/build/MyVerification.xcresult CODE_SIGN_IDENTITY=- test
```

UI 测试使用独立偏好域与明确的 Debug 启动标记，不清理真实用户偏好。权限异常通过适配器复现；四个系统权限用例以 `--system-permissions` 运行真实系统请求，允许与拒绝需要独立安装。模拟器本地签名无需开发证书；Release 编译排除这些测试适配器。每次运行的结果目录需使用新名称。

## 结构与维护

- `ios/Leanora/App`：入口、依赖注入、Tab 导航。
- `Core/Domain`：训练/饮食/身体与设备健康状态值对象；`Persistence`：本地 SwiftData actor 与迁移；`Backup`：版本化 JSON、校验与冲突规则。
- `Core/Preferences` / `Notifications`：偏好缓存与通知；`Integrations/HealthKit`：授权、原生读写、观察器与同步协调；细节见 [健康合同](docs/health-sync.md)。
- `Features/Training` / `Workout` / `History`：动作库、模板、周计划、超级组、逐组训练、计时、恢复与历史。
- `Features/Nutrition` / `Body` / `Today`：来源食物库、营养快照、餐次、身体测量及同口径趋势；纯计算器和统计位于 `Core/Nutrition` / `Analytics`。
- `Design` / `Resources`：原创设计、系统图标、字符串、权限与隐私配置。
- `ios/LeanoraTests` / `LeanoraUITests`：基础服务和页面流程测试。
- `docs`：当前范围、来源、流程与实际验证记录。

工程文件已生成，无需额外工具即可打开。新增文件后若需重新生成工程，可运行 `ruby app/scripts/generate_project.rb`，开发环境需安装 MIT 许可的 `xcodeproj` gem。重绘原创图标使用 `swift app/scripts/GenerateBrandAssets.swift`。

最新证据见 [最终验收记录](docs/qa/release-acceptance.md)、[发布清单](docs/release-checklist.md)、[交互调整](docs/experience-refresh.md)。此前阶段状态见 [阶段 4、5 验证记录](docs/qa/phase-four-five-verification.md)、[训练/饮食/身体功能合同](docs/workout-and-nutrition.md)、[训练计划合同](docs/training-plans.md)、[数据基础合同](docs/data-foundation.md)。U1 的物理设备门槛仍见 [阶段 1 验证记录](docs/qa/phase-one-verification.md)。产品范围见 [product-scope.md](docs/product-scope.md)。

常规功能回归排除四个系统权限方法，再分别使用独立安装运行 Health 允许、Health/通知拒绝、通知允许；具体方法与运行口径见 [最终验收记录](docs/qa/release-acceptance.md#重现)。通知横幅及锁屏送达仍需真机记录，系统允许或存在待送达请求不等于已送达。

容量验证：`LEANORA_SCALE_TESTS=1 swift test --package-path app --scratch-path app/build/SwiftPM --disable-swift-testing --filter CapacityTests`。普通回归明确跳过两项大容量用例，单独执行保留实测数据。未签名 iPhone Archive：`bash app/scripts/archive_release.sh`；不会上传或操作开发者账号。

签名 Archive 可用 Xcode Organizer 生成；导出本地发行候选：`bash app/scripts/export_testflight_candidate.sh <signed.xcarchive> <不存在的导出目录>`。脚本使用已配置团队获取发行签名资源，导出选项明确为 `destination=export`。政策网页从 Markdown 重建：`python3 app/scripts/render_privacy_policy.py`。
