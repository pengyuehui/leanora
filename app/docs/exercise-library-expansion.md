# 动作库扩充与指导素材

目标：扩充内置动作数据，并让每个内置动作都有可离线查看的指导图片。保留原 100 个动作的 UUID、名称、计量与分类，避免影响模板、归档状态及训练历史。

## 实现步骤

- [x] 核实 openGym、Free Exercise DB、Workout Guide 的数据与媒体许可。
- [x] 固定上游版本、记录来源，生成扩充目录与逐动作图片索引。
- [x] 加入动作详情、选择动作及训练过程的指导入口。
- [x] 验证资源覆盖、原目录兼容、搜索筛选、备份与页面交互。
- [x] 按项目要求提交并推送源码和允许再分发的素材。

## 内容边界

openGym 仅参考产品分类与指导入口。其 Gym visual 图片及动画不进入 Leanora。Free Exercise DB 的公开领域数据与照片用于扩充；Workout Guide 的 CC BY-SA 4.0 插图补足照片库未覆盖的原有动作，保留 Bryl Lim 和 Everkinetic 署名、许可链接与修改记录。应用 Swift 代码继续按 MIT 发布，插图许可独立保留。

原有动作添加项目整理的中文提示。新条目保留上游名称和英文步骤，部分常用名称补充中文；不将未翻译的内容伪装成完整中文教学。无图的上游条目暂不引入。辅助双杠的图片明确标注为基础双杠动作轨迹，器械设置在文字步骤说明；不使用上游误标为辅助双杠的坐姿器械下压插图。哑铃罗马尼亚硬拉与壶铃摆动仅选取核看过的两个姿态，不将中间帧插值成视频。图片与说明不写入用户业务备份，依固定动作 ID 从随包目录读取。

## 实际范围

| 项目 | 数量或行为 |
| --- | --- |
| 内置动作 | 882，较原库增加 782 |
| 图片指导覆盖 | 882 / 882 |
| 独立图片 | 1765 张：Free Exercise DB 1746 张，Workout Guide 19 张 |
| 图片大小 | 72,036,917 字节，约 68.7 MiB |
| 中文名称 | 284 个；其余保留上游英文名称和别名 |
| 中文提示 | 原有 100 个动作；其他条目有原文时展示英文步骤 |
| 新增筛选 | 难度、动作类型；细分肌群筛选同时考虑指导资料的主要及辅助肌群 |
| 原有数据 | 100 个动作原字段逐项相等；不批量写入用户库，不修改历史快照 |
| 排除条目 | Kettlebell Halo、Kettlebell Halo With Overhead Extension、Kettlebell Overhead Triceps Extension：上游没有图片 |

图片均为静态照片或姿态插图。全屏查看支持切换图片、返回原页；没有播放伪造的动作视频。部分上游动作无文字步骤，保留其图片，不自动编造教学文案。

## 数据与代码

- `content/exercises/leanora-v1.json`：原 100 条数据基线。
- `content/exercises/source-lock.json`：上游修订、输入 SHA-256、补充素材 Git blob 哈希。
- `content/exercises/sources/`：固定版本的原始数据及逐帧署名。
- `content/exercises/legacy-guides.tsv`、`chinese-names.tsv`：可编辑的映射、中文名及提示。
- `Resources/Catalog/exercises.json`：生成的 882 条记录目录。
- `Resources/Catalog/exercise-guides.json`：按动作 ID 分离的图示、肌群、难度、步骤及许可。
- `Resources/ExerciseMedia/`：本地图片、完整许可及逐文件校验清单。
- `Core/Training/ExerciseGuideCatalog.swift`：一次加载、路径约束与本地图片 URL；不请求网络。
- `Features/Training/ExerciseGuidanceView.swift`：统一图示、分页、大图、步骤和来源展示。

新条目 ID 由来源条目 ID 使用固定命名空间 UUID v5 生成。计量类型依据来源分类、器械与显式例外映射：有氧记录时间和距离，拉伸及静态动作记录时长，自重/悬吊动作记录次数，负重动作记录负重和次数。器械只是支撑物的悬吊划船、滚腹等不会因有器械而被视作外部负重；上游 Iron Cross 是哑铃动作，使用负重与次数。原有 100 条计量类型不改动。

## 重建与校验

App 与 Xcode 构建不需要第三方运行时依赖，所有生成结果已提交。只有重建内容图片时需要 Python 和 Pillow 12.3.0（开发依赖）。

1. 从固定修订取回原始 ZIP：`https://codeload.github.com/yuhonas/free-exercise-db/zip/f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5`。保存为 `app/build/exercise-sources/free-exercise-db.zip`，其 SHA-256 为 `ad2770ed89335c8b79da12854cc684d419e0f482de69b826c4a31bfac2405eab`。
2. 使用装有 Pillow 12.3.0 的 Python 执行 `python3 app/scripts/build_exercise_catalog.py --download`。它从 ZIP 读取图片，仅下载锁定版本的补充 PNG 与许可证，核对 Git blob；不会执行上游代码。
3. 执行 `python3 app/scripts/validate_exercise_catalog.py`，检查旧字段、路径、许可、图片覆盖与哈希。
4. 执行 `swift test --package-path app --scratch-path app/build/SwiftPM --disable-swift-testing`，验证生产加载、图片解码、模板/训练/备份链路。

首次下载后的缓存可复用；不传 `--download` 时仅使用本地输入。图片由 ImageIO 缩略解码，内存缓存限制为 24 MiB，不会把整套图片同时载入内存。素材与 App 内截图的署名、使用范围见[第三方清单](../THIRD_PARTY_NOTICES.md)。

本次仅更新源码及本地构建，没有替换已送审的 App Store 1.0（4）。实际验证记录见 [QA 报告](qa/exercise-library/README.md)。

2026-10-26 发行补记：上述动作库已包含在 App Store 1.1（5）中，签名、正式发行包逐图哈希及 Apple 二进制验证通过，已正式提交并等待审核。详见 [1.1 送审记录](qa/appstore-submission-1.1.md)。
