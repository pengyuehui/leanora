# 依赖与内容来源

更新：2026-10-22。交付代码目录为 `app/`。用户已确认项目源码按仓库 [MIT 许可证](../../LICENSE) 公开发布；第三方动作数据与媒体按[各自许可](../THIRD_PARTY_NOTICES.md)保留。此前闭源路线为历史决策，独立实现及第三方来源边界继续保留。上级目录的 `sources/`、`samples/`、`analysis/` 属于研究资料，不编译、打包或复制进 App。

| 内容/依赖 | 来源与许可/使用依据 | 负责人（角色） | 本阶段状态 |
|---|---|---|---|
| 应用 Swift 代码、测试、界面文案、页面结构 | 本项目独立实现；MIT | iOS 开发负责人 | 已实现；无第三方源码移植 |
| Leanora 字标与几何 L 图形 | 项目原创；图标由 `scripts/GenerateBrandAssets.swift` 生成 | 设计负责人 | 已制作；正式品牌商标另行确认 |
| 系统图标 | Apple SF Symbols，通过 `Image(systemName:)` 使用；遵守 Apple 的平台使用规则 | iOS 开发负责人 | 仅系统原生使用，无外部素材包 |
| 系统字体 | Apple 平台内置字体，由系统渲染 | 设计负责人 | 未嵌入第三方字体 |
| SwiftUI / Observation / HealthKit / UserNotifications / Foundation | Apple 系统 SDK；受 Apple 开发者及 SDK 协议约束 | iOS 开发负责人 | 唯一运行时依赖来源 |
| xcodeproj 1.27.0 | CocoaPods/Xcodeproj，MIT；仅本机生成工程的开发工具，不链接到 App | iOS 开发负责人 | 已提供工程文件，无需此工具即可在 Xcode 打开 |
| OpenGym 功能研究 | `alexpcosta/opengym` commit `678bf5bf10446e8997a77d43e89c9b2721d8d0fc`；AGPL-3.0 | 产品负责人 | 只参考能力；不含其代码、测试、动作库、图标或页面资源 |
| 训记/薄荷功能研究 | 上级 `analysis/训记与薄荷-开发参考.md` 与公开安装包研究 | 产品负责人 | 只参考交互与对象关系；不接私有接口，不包含其内容库 |
| 原有动作目录 v1 | 原始 100 条保存在 `content/exercises/leanora-v1.json`；来源引用 `leanora:catalog/exercises/v1`，项目自有内容 | 本轮开发自检；内容负责人复核待落实 | 原 100 条 ID 与全部原字段保留；独立添加中文提示，图片来源单独记录 |
| 扩充动作目录 | Free Exercise DB commit `f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5`；Unlicense，原名称、肌群、器械、分类与英文步骤 | 本轮开发自检；内容负责人专业复核待落实 | 总量 882 条；284 个名称含中文，原 100 条有中文提示；无图的 3 个上游条目未引入 |
| 基础食品目录 v1 | USDA FoodData Central SR Legacy 2018 官方 ZIP；CC0-1.0；每条保留 FDC URL、原营养值和份量 | 本轮开发自检；商业发布前由内容负责人专业复核（待指定具体人员） | U5 随包 300 条，其中 29 条独立中文名，原英文别名可搜索；输入 SHA256 与重建方法已记录 |
| 动作照片 | Free Exercise DB，同上固定版本，Unlicense | 本轮检查可解码、路径与哈希；逐动作专业复核待落实 | 1746 张原图缩放、压缩并移除元数据，随 App 内置 |
| 补充动作插图 | Workout Guide commit `aac599224bb9780305239607ef98540b7e0ce389`；Bryl Lim / Everkinetic，CC BY-SA 4.0 | 本轮核看选用姿态；内容负责人复核待落实 | 7 个原有动作共 19 张 PNG，保留原文件、署名与完整许可；来源页可查看 |
| Pillow 12.3.0 | Pillow 开源图像工具；仅重建动作图片的开发依赖，不链接进 App | 开发负责人 | 随包图像为静态数据；运行时仍仅使用 Apple SDK |

来源字段的持续要求：每项将来引入的第三方依赖或内容必须记录名称、来源 URL、版本/修订、许可、允许的使用范围、审核角色与审核日期。来源不明确的内容不进入包内目录。

本清单只记录当前源码交付物；未来品牌食品库、视频或正式商标需另行确认。角色负责人需在商业发布前落实到具体人员。此次动作更新没有替换已送审的 1.0（4）构建。

动作更新提供检索、筛选、图示与来源步骤。开发验证覆盖 ID 唯一、原 100 条兼容、计量类型、媒体解码与哈希、来源及许可、模板和备份链路；不宣称已完成专业教练审定。新图片与步骤按动作 ID 从随包目录读取，不写入用户业务记录或历史快照。辅助双杠的基础动作轨迹图会明确标注范围；核看发现的上游误标插图没有引入。完整规则见[动作库说明](exercise-library-expansion.md)。

## 目录隔离检查

Xcode 工程只引用 `app/ios/Leanora`、`LeanoraTests` 与 `LeanoraUITests` 内的源文件和资源。没有外部 Swift Package、CocoaPods 或远程脚本。Swift Package 测试工具也只编译同一份项目基础服务代码。

开发工具许可原文：[Xcodeproj LICENSE](https://github.com/CocoaPods/Xcodeproj/blob/1.27.0/LICENSE)。Apple 系统图标说明：[SF Symbols](https://developer.apple.com/sf-symbols/)。OpenGym 研究来源见主开发计划中的许可索引。

## 食物目录重现与边界

官方输入：[SR Legacy 2018 ZIP](https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_json_2018-04.zip)。[USDA 官方许可](https://fdc.nal.usda.gov/api-guide/#licensing) 列明 CC0。取回日期 2026-10-20；文件 SHA256、数量与规则见 [food-catalog-manifest.json](food-catalog-manifest.json)。执行 `python3 app/scripts/build_food_catalog.py /path/to/official.zip` 可重建，脚本无需 API 密钥。目录没有营养插补；份量保持 USDA 的原数量和克数，不从杯/体积猜测密度。

中文名称为本项目独立制作，保留生/熟、部位等差异；其余采用原文，未包装成中国品牌食物库。开发验证包含 ID 唯一、范围、来源、份量和营养计算，尚不等于营养专业审定。没有取用薄荷或训记的食物、动作数据和媒体。
