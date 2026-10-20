# REA 已安装

2026-10-20，本机安装并验证 REA **6.7.0**。来源：[morluto/rea 官方仓库](https://github.com/morluto/rea)及其 `rea-agents` npm 包。

| 项目 | 位置或状态 |
|---|---|
| REA 包 | `/Users/pengyuehui/Downloads/leanora/tools/rea/node_modules/rea-agents` |
| 可直接使用的命令 | `/Users/pengyuehui/Downloads/leanora/scripts/rea` |
| Node | 复用 Codex 自带的 24.19.0，REA 独立指定运行环境 |
| Java | 复用本机 Temurin JDK 21.0.2 |
| JADX | 工作区 `tools/android/jadx-headless-mcp-0.7.1-all.jar` |
| Codex MCP | 已增加 `~/.codex/config.toml` 的 `mcp_servers.rea` |
| 配置备份 | `~/.codex/config.toml.rea.backup` |
| 工作流说明 | `~/.agents/skills/reverse-engineer-anything`，版本 42 |

JADX SHA-256 已与 REA 固定元数据一致：

```text
6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75
```

验证结果：`doctor --client codex --skill --json` 的 `healthy: true`；独立 MCP 会话实际完成初始化，发现 207 个工具，并成功执行两个 APK 的静态包解析、薄荷 SQLite 检查及证据导出。[验证记录](/Users/pengyuehui/Downloads/leanora/analysis/evidence/rea-doctor.json)

重启 Codex 后加载新增的 MCP 和工作流。本轮已通过独立本地 MCP 会话完成分析，无需为了查看报告而重启。

```sh
cd /Users/pengyuehui/Downloads/leanora
./scripts/rea --version
./scripts/rea inspect-android-package /Users/pengyuehui/Downloads/com.boohee.one_15.8.1.apk --json
./scripts/rea inspect-sqlite-database /Users/pengyuehui/Downloads/leanora/analysis/inputs/bhdb.sqlite --json
```

安装保存在当前工作区，Codex 的 MCP 注册引用这里的文件；移动或删除此目录后需要更新注册路径。此安装支持本次 Android 分析；Hopper、Ghidra、IDA 等其他分析引擎未配置。

分析入口：[训记与薄荷开发参考](/Users/pengyuehui/Downloads/leanora/analysis/训记与薄荷-开发参考.md)。
