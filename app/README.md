# Leanora

原生 iPhone 训练与饮食日记，闭源商业路线下的独立实现。当前实现 **U1–U3**：首次使用、五个 Tab、真实权限入口、事务/恢复/JSON 备份，以及动作库、训练模板、周安排和单次改期。「训练」可搜索动作、创建模板并启动当天训练；「我的 → 数据管理」可备份资料。逐组执行、饮食录入和 Health 样本同步按 U4–U7 实现。

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

UI 测试使用独立偏好域与明确的 Debug 启动标记，不清理真实用户偏好。权限异常通过适配器复现；另外两个用例以 `--system-permissions` 运行真实系统请求，应选择全新测试模拟器。模拟器本地签名无需开发证书；Release 编译排除这些测试适配器。每次运行的结果目录需使用新名称。

## 结构与维护

- `ios/Leanora/App`：入口、依赖注入、Tab 导航。
- `Core/Domain`：训练/饮食/身体与设备健康状态值对象；`Persistence`：本地 SwiftData actor 与迁移；`Backup`：版本化 JSON、校验与冲突规则。
- `Core/Preferences` / `Notifications`：偏好缓存与通知；`Integrations/HealthKit`：系统授权适配。
- `Features/Training`：动作库与自定义/归档、模板目标与排序/复制、周计划/单次改期、已开始训练快照；其余 Features 为首次使用、今天、日记空状态与设置。
- `Design` / `Resources`：原创设计、系统图标、字符串、权限与隐私配置。
- `ios/LeanoraTests` / `LeanoraUITests`：基础服务和页面流程测试。
- `docs`：当前范围、来源、流程与实际验证记录。

工程文件已生成，无需额外工具即可打开。新增文件后若需重新生成工程，可运行 `ruby app/scripts/generate_project.rb`，开发环境需安装 MIT 许可的 `xcodeproj` gem。重绘原创图标使用 `swift app/scripts/GenerateBrandAssets.swift`。

详细状态见 [阶段 3 验证记录](docs/qa/phase-three-verification.md)、[训练计划合同](docs/training-plans.md)、[数据基础合同](docs/data-foundation.md)。U1 的物理设备门槛仍见 [阶段 1 验证记录](docs/qa/phase-one-verification.md)。产品范围见 [product-scope.md](docs/product-scope.md)。
