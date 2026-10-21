# Leanora

原生 iPhone 训练与饮食日记，闭源商业路线下的独立实现。已实现 U1–U8 的本机功能：本地事务与恢复、JSON/CSV、100 动作与 300 食品、模板/周计划、逐组训练/计时/历史、饮食与身体趋势、Apple Health 读写/队列/恢复核对、分离清理。界面按记录主流程重新组织。真机健康、最低系统、内容专业复核与签名 TestFlight 是独立发布门槛，当前不宣称已发布。

## 打开与运行

打开 `ios/Leanora.xcodeproj`，选择共享 Scheme **Leanora**。最低 iOS 18，Swift 6；本次构建工具为 Xcode 27.1。没有第三方运行时依赖。

- 模拟器：先在 Xcode Settings → Components 安装 iOS Runtime，然后选择可用 iPhone 模拟器运行。
- 真机：在 Signing & Capabilities 选择自己的 Developer Team，确认 HealthKit 能力及开发 Bundle ID；连接已开启开发者模式的 iPhone。
- `app.leanora.dev` 为开发标识，不是已注册的商业 App 标识。代码没有签名密钥或团队账号。

## 验证

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
