# 国行 Mac 开启 Apple Intelligence 与新版 Siri（Siri AI）完整实录

> 一台**国行 Mac Studio（M5 Ultra）**，在 macOS 27 上从"Siri AI is not available"到新版 Siri 对话、写作工具、Private Cloud Compute（PCC）、Siri 联网搜索、ChatGPT 扩展全部可用的完整过程。
> 包括准备工作、每一步命令、真实踩过的坑，以及重启后资格丢失的自动修复。

[English summary](README.en.md)

---

## ⚠️ 先读这里（风险与免责声明）

- 本方法需要**降低 Mac 的启动安全等级**、**部分关闭系统完整性保护（SIP）**，并加载一个**第三方内核扩展**。这会削弱 macOS 的安全防护，理论上可能导致系统不稳定、无法启动、部分 App（尤其 iPhone/iPad App）异常，或影响保修与售后。
- 这是**绕过 Apple 地区限制**的非官方做法，Apple 随时可能通过系统更新或服务端策略让它失效。Apple 官方说明：国行设备上的 Apple Intelligence 受监管要求限制（见下文）。请自行了解并遵守你所在地的法律法规与 Apple 的服务条款。
- 本仓库只记录一台机器的真实经历，**不保证在你的机器上同样有效**。所有操作风险由你自己承担。动手前请务必完成完整备份。
- 本仓库**不分发**任何第三方二进制或内核扩展；核心内核扩展请从上游项目自行获取源码并自行编译。

---

## 哪些地区/情况会被限制？

根据 Apple 官方支持文档（2026 年 9 月发布版本）：

| 情况 | Apple Intelligence | Siri AI（新版 Siri，Beta） |
|---|---|---|
| **在中国大陆购买的设备（国行）** | ❌ 不可用（无论人在哪里） | ❌ 不可用 |
| 非国行设备，但人在中国大陆**且** Apple 账户地区为中国大陆 | ❌ 不可用 | ❌（账户地区为中国大陆即不可用） |
| Apple 账户地区为中国大陆 | — | ❌ 不可用 |
| 欧盟（EU） | ✅ Mac 可用 | ✅ **Mac 可用**（设备语言与 Siri 语言须为英文）；iPhone/iPad/Watch 上不可用 |
| 设备语言 ≠ Siri 语言，或语言不受支持 | ❌ | ❌（Siri AI 目前只支持英文） |
| 其他地区 | 官方称"可用性因地区和平台而异"，未列出其他明确排除的国家 | 需加入候补（waitlist），等待时间不定 |

所以**真正需要这套方法的基本只有国行设备**（以及账户地区在中国大陆的用户）。来源：
[Apple Intelligence 可用性](https://support.apple.com/en-us/121115) ·
[Siri AI (Beta)](https://support.apple.com/en-us/127893)

---

## 我的环境

| 项 | 值 |
|---|---|
| 设备 | Mac Studio（M5 Ultra，Mac17,15，96GB，国行 CH/A） |
| 系统 | macOS 27.0.1（26A434） |
| 系统语言 / Siri 语言 | English (US) / English (US) |
| Apple 账户地区 | 非中国大陆 |
| 网络 | 中国大陆家庭宽带与公司网络；代理工具 Surge for Mac；同时使用 Tailscale |
| 时间 | 2026 年 10 月 9 日～12 日 |

---

## 原理一图看懂

Apple Intelligence / Siri AI 要跑起来，要过**三道关**：

```
① 资格关（本机）      eligibilityd 判断：设备地区、账户地区、语言、机型……全部满足才"有资格"
        │              国行机卡在"设备地区 = CH"
        │              → 用 RegionSpoof 内核扩展把 IORegistry 里的 region-info 从 CH/A 改成 LL/A（美版）
        ▼
② 资源关（下载）      有资格后系统才会下载 Apple Intelligence 模型（数 GB）
        ▼
③ 网络关（云端）      新版 Siri、写作工具的云端部分、PCC、联网搜索、ChatGPT 扩展都要访问 Apple / OpenAI 服务
                       在中国大陆需要稳定、正确分流的网络环境，否则"能打开但一用就报错"
```

本仓库每一关都有详细步骤，并额外解决了两个上游项目没有覆盖的问题：
- **普通重启后资格会丢**（eligibilityd 比内核扩展更早读取地区并缓存），需要一次"用户空间重启"，本仓库提供了开机自动修复。
- **Siri 联网搜索和 ChatGPT 扩展登录失败**（沙盒端口限制 + DNS 污染 + 分流规则），本仓库给出了根因和配置。

---

## 步骤目录

| # | 步骤 | 大约耗时 |
|---|---|---|
| 1 | [准备工作：备份、账户、语言、记录原始安全状态](docs/01-准备工作.md) | 30 分钟+ |
| 2 | [从源码编译 RegionSpoof 内核扩展](docs/02-编译内核扩展.md) | 15 分钟 |
| 3 | [进恢复模式：降低启动安全、允许内核扩展](docs/03-恢复模式设置.md) | 15 分钟 |
| 4 | [安装并批准内核扩展](docs/04-安装并批准内核扩展.md) | 15 分钟（含一次重启） |
| 5 | [激活资格（用户空间重启）并下载模型](docs/05-激活资格与下载模型.md) | 10 分钟 + 下载时间 |
| 6 | [网络配置：PCC、Siri 联网搜索、ChatGPT 扩展](docs/06-网络配置.md) | 30 分钟 |
| 7 | [重启后自动恢复资格（可选，已实测）](docs/07-重启后自动恢复.md) | 5 分钟 |
| 8 | [故障排查：症状 → 原因 → 解法](docs/08-故障排查.md) | — |
| 9 | [完全回退到原厂安全状态](docs/09-完全回退.md) | 30 分钟 |

给 AI 助手用的 Skill：
- [`skills/china-mac-apple-intelligence/`](skills/china-mac-apple-intelligence/SKILL.md)：把本指南写成 AI 助手（如 Claude Code）可执行的"关卡式"操作手册。AI 先只读体检、判断卡在哪一关、每次只给下一步；所有需要管理员密码、恢复模式、系统批准的操作都**由你本人执行**，AI 不会代输密码。安装方法：把该文件夹复制到 `~/.claude/skills/`，然后对 AI 说"帮我在国行 Mac 上开 Apple Intelligence"。网络部分只在 Surge for Mac 上验证过。

辅助脚本：
- [`scripts/check-status.sh`](scripts/check-status.sh)：只读体检，一次看清 SIP、地区、内核扩展、资格、语言。
- [`scripts/auto-eligibility-fix/`](scripts/auto-eligibility-fix/)：开机自动恢复资格（第 7 步）。
- [`examples/surge-apple-intelligence.conf`](examples/surge-apple-intelligence.conf)：Surge 分流规则片段（不含任何节点信息）。

---

## 最终效果（2026-10-12 验收，10-21 更新）

- ✅ 系统设置 → Siri 显示 **Powered by Apple Intelligence**，Siri AI App 可以新建对话
- ✅ 新版 Siri 生成、连续追问
- ✅ 写作工具、Private Cloud Compute 云端功能
- ✅ Siri 联网搜索：新闻、天气、"Apple 的 CEO 是谁"
- ✅ ChatGPT 扩展登录（ChatGPT Pro 账户）
- ✅ 家庭网络与公司网络（路由器层已有透明代理）下均验证通过
- ✅ 普通重启后资格会丢，但第 7 步的开机任务会自动做一次用户空间重启恢复（10-15～10-20 三次真实重启实测通过）
- ℹ️ 附带发现：设备地区改成美版后，**Apple News（含 News+）** 在这台 Mac 上也能打开了（News 流量同样分到美国出口，账户为非中国大陆）。这不是本指南的目标，仅作记录

---

## 致谢

- 内核扩展思路与源码：[SkyBlue997/enableMacosAI](https://github.com/SkyBlue997/enableMacosAI)（本文基于提交 `9c617ed`）。上游仓库没有声明开源许可证，因此本仓库**只链接、不复制**其代码。
- 本文由设备主人在 AI 助手（Claude、Codex）协助下完成实操、排错与整理。

## 许可

- 文档：[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- `scripts/` 与 `examples/` 中的脚本与配置：[MIT](LICENSE)
