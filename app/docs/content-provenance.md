# 依赖与内容来源

更新：2026-10-20。交付代码目录为 `app/`。上级目录的 `sources/`、`samples/`、`analysis/` 属于研究资料，不编译、打包或复制进 App。

| 内容/依赖 | 来源与许可/使用依据 | 负责人（角色） | 本阶段状态 |
|---|---|---|---|
| 应用 Swift 代码、测试、界面文案、页面结构 | 本项目独立实现 | iOS 开发负责人 | 已实现；无第三方源码移植 |
| Leanora 字标与几何 L 图形 | 项目原创；图标由 `scripts/GenerateBrandAssets.swift` 生成 | 设计负责人 | 已制作；正式品牌商标另行确认 |
| 系统图标 | Apple SF Symbols，通过 `Image(systemName:)` 使用；遵守 Apple 的平台使用规则 | iOS 开发负责人 | 仅系统原生使用，无外部素材包 |
| 系统字体 | Apple 平台内置字体，由系统渲染 | 设计负责人 | 未嵌入第三方字体 |
| SwiftUI / Observation / HealthKit / UserNotifications / Foundation | Apple 系统 SDK；受 Apple 开发者及 SDK 协议约束 | iOS 开发负责人 | 唯一运行时依赖来源 |
| xcodeproj 1.27.0 | CocoaPods/Xcodeproj，MIT；仅本机生成工程的开发工具，不链接到 App | iOS 开发负责人 | 已提供工程文件，无需此工具即可在 Xcode 打开 |
| OpenGym 功能研究 | `alexpcosta/opengym` commit `678bf5bf10446e8997a77d43e89c9b2721d8d0fc`；AGPL-3.0 | 产品负责人 | 只参考能力；不含其代码、测试、动作库、图标或页面资源 |
| 训记/薄荷功能研究 | 上级 `analysis/训记与薄荷-开发参考.md` 与公开安装包研究 | 产品负责人 | 只参考交互与对象关系；不接私有接口，不包含其内容库 |
| 基础动作目录 v1 | `Resources/Catalog/exercises.json`；Leanora 独立整理通用名称、别名与分类；来源引用 `leanora:catalog/exercises/v1`，项目自有内容 | 本轮开发自检；商业发布前内容负责人复核 | U3 随包 22 条，固定 UUID、版本与来源；无第三方文案/图片/动画，无动作教学 |
| 食品营养库、动作媒体 | 尚未引入；需保留来源、许可、修订及审核记录 | 内容负责人（待指定具体人员） | U5/发布前依赖，当前数量为 0 |

来源字段的持续要求：每项将来引入的第三方依赖或内容必须记录名称、来源 URL、版本/修订、许可、允许的使用范围、审核角色与审核日期。来源不明确的内容不进入包内目录。

本清单只记录当前交付物；未取得未来食品库、动作媒体或正式商标的授权。角色负责人需在商业发布前落实到具体人员。

本轮基础动作仅提供检索和记录分类。开发自检验证 22 个 ID 唯一、计量类型与本地格式合法、来源字段完整；不宣称已经过专业教练审核，也不把它作为动作教学或训练处方。首版约 100 动作是发布内容目标，U3 按计划允许先交付少量自有条目。

## 目录隔离检查

Xcode 工程只引用 `app/ios/Leanora`、`LeanoraTests` 与 `LeanoraUITests` 内的源文件和资源。没有外部 Swift Package、CocoaPods 或远程脚本。Swift Package 测试工具也只编译同一份项目基础服务代码。

开发工具许可原文：[Xcodeproj LICENSE](https://github.com/CocoaPods/Xcodeproj/blob/1.27.0/LICENSE)。Apple 系统图标说明：[SF Symbols](https://developer.apple.com/sf-symbols/)。OpenGym 研究来源见主开发计划中的许可索引。
