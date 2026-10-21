---
name: china-mac-apple-intelligence
description: Guide a user, step by step and evidence-first, through enabling Apple Intelligence and Siri AI (new Siri) on a China-mainland (国行, CH/A) Apple-silicon Mac running macOS 27, and diagnose why it is not working. Use this whenever the user mentions a 国行/China-region Mac together with Apple Intelligence, Siri AI, 新版 Siri, "Siri AI is not available", RegionSpoof / enableMacosAI, eligibility (GREYMATTER) answer 2, Apple Intelligence lost after reboot, Siri web search (天气/新闻/CEO) failing with "Something's wrong" while chat works, or the ChatGPT extension failing at the last sign-in step in China — even if they only describe the symptom. Caveats to tell the user up front: the network part was verified only with Surge for Mac; the boot-time auto-fix was verified across three real reboots on one machine. 用于：国行 Mac 开启 Apple Intelligence / 新版 Siri、资格为 2、重启后失效、Siri 联网搜索报错、ChatGPT 扩展登录失败。
---

# 国行 Mac 开启 Apple Intelligence / Siri AI（关卡式操作手册）

你在帮一位用户把**国行 Apple 芯片 Mac（macOS 27）**上的 Apple Intelligence 与新版 Siri（Siri AI）打开，或排查为什么没打开。这套方法来自一台国行 Mac Studio（M5 Ultra，macOS 27.0.1）的真实完整实操，完整文档在本仓库 `docs/`：

- 如果本 Skill 位于仓库内（`<仓库>/skills/china-mac-apple-intelligence/`），文档在 `../../docs/`。
- 否则读线上版：https://github.com/RonZhu/apple-intelligence-china-mac/tree/main/docs

本文件只负责"判断卡在哪一关、下一步做什么、做完怎么核对"。具体命令和解释在文档里，**照文档给命令，不要凭记忆改写**。

---

## 硬规则（为什么：这是在改别人电脑的安全设置，错一步可能无法启动或丢数据）

**你可以自己做的**：只读检查（本 Skill 的 `scripts/check-status.sh`、`csrutil status`、`ioreg`、`kmutil showloaded`、`scutil --dns`、`scutil --proxy`、读日志、读配置文件）；不需要管理员权限的编译与签名（docs/02）。

**必须交给用户本人做的**（你给出**完整、可复制的命令或界面步骤**，用户自己在"终端"或界面里操作，做完告诉你，你再读一次真实状态）：
- 任何 `sudo` 命令（复制扩展到 `/Library/Extensions`、`kmutil load`、`launchctl reboot userspace`、安装自动修复任务等）。**不要自己运行 sudo，不要让用户把密码发给你，不要替用户输入密码。**
- 恢复模式里的一切（启动安全性实用工具、`csrutil`）。
- 系统设置里的"允许"、批准网络扩展、添加 VPN 配置、登录任何账户。
- 用户空间重启、普通重启（会退出所有 App——先提醒用户保存工作）。
- 在 Siri 里提问做验收。

**绝对不要建议**：
- `csrutil disable`（完全关闭 SIP）、`csrutil authenticated-root disable`、任何 `boot-args`（尤其 `amfi_get_out_of_my_way=1`，会弄坏 PCC）。只需要 `csrutil enable --without kext`。
- 运行上游项目的一键 `install.sh`（会改 boot-args、强制重启服务、吞掉错误）；也不要用来历不明的预编译 kext——从源码自己编译（docs/02）。
- 为了"COUNTRY_LOCATION 输入是 2"去改定位、改 countryd 缓存、改账户地区之外的设置——最终以两个 domain 的 answer 为准，作者机器上该输入一直是 2 但资格是 4。
- 直接改 `eligibility.plist` 数值（无效，会被重算）。
- 用户同时开着 Tailscale 时关闭 Surge 系统代理（会删掉各网络服务的代理却不写回，见 docs/06 §6.5）。
- 把 `skip-proxy api-siri-prod.apple.com` 加进 iPhone/iPad 用的配置（iOS 忽略进程规则，会弄坏手机上的 Siri 搜索）。
- 手动删 Preboot 卷文件、用"panic medic"类命令清空第三方扩展。

**每一步都要验证**：用户说"做完了"之后，重新读真实状态再进入下一步；读出来和预期不符就停下来解释，不要往前推。

---

## 开始：先体检，再说话

1. 运行只读体检（不需要 sudo；若资格文件读不到，请用户自己运行 `sudo bash <路径>/check-status.sh` 并把输出贴回来）：

   ```bash
   bash scripts/check-status.sh
   ```

2. 向用户确认两件脚本查不到的事：Apple 账户地区是不是中国大陆；有没有可用的备份（Time Machine 或可启动的旧机）。
3. 用下表判断当前关卡，**只告诉用户下一件事**，不要一次把九个步骤全倒给他。

## 关卡判断表

按顺序检查，第一个不满足的就是当前关卡：

| # | 检查 | 满足的样子 | 不满足 → 做什么 |
|---|---|---|---|
| 0 | 机型/系统 | Apple 芯片（M1 及以后），macOS 27 | Intel 或旧系统：说明不支持，停止 |
| 1 | 前置条件 | 账户地区非中国大陆；`AppleLanguages` 首项 en-US 且 Siri 语言也是英文；有备份；已记录原始 `csrutil status`、`bputil -d`、region-info | docs/01。语言或账户不对时资格永远是 2 |
| 2 | 允许加载 ad-hoc 内核扩展 | `csrutil status` 中 **Kext Signing: disabled**，且启动安全允许用户管理内核扩展 | 先编译（docs/02），再请用户进恢复模式（docs/03：先启动安全性实用工具，再 `csrutil enable --without kext`，一次做完） |
| 3 | 扩展已安装并加载 | 体检显示"已加载"；region-info = **LL/A**，country-of-origin = **USA** | docs/04：用户执行复制与 `kmutil load`（首次退出码 27 是正常的）→ 系统设置"允许" → 重启 |
| 4 | 资格 | GREYMATTER 与 SIRI_WITH_APP_INTENTS 都是 **4** | 若地区已是 LL/A 但资格仍 2：请用户保存工作后运行 `sudo launchctl reboot userspace`（docs/05）。不要试 `launchctl kickstart`（SIP 下返回 150）。仍是 2 → 回查关卡 1 |
| 5 | 资源 | 系统设置 → Siri 显示 *Powered by Apple Intelligence*，资源下载完成；Siri AI App 能新建对话 | 等待下载；出现 Join Waitlist 只能等（服务端分批） |
| 6 | 网络 | 用户在 Siri 里：不联网的生成问题、*Who is the CEO of Apple*、*今天纽约天气怎么样* 都能回答；需要时 ChatGPT 扩展能登录 | docs/06，按下文"网络诊断"取证 |
| 7 | 重启持久性 | 普通重启后资格仍是 4 | 每次开机后用户手动 `sudo launchctl reboot userspace`，或安装 `scripts/auto-eligibility-fix/`（docs/07，作者机器已在三次真实重启中验证；开机 15 分钟后才能安装） |

**全部满足时**：明确告诉用户"各关都已通过，不需要再改任何东西"，给出验收方法（在 Siri 里问上面两个问题），提醒关卡 7 的注意事项。不要为了"做点什么"而建议任何修改。

## 网络诊断（关卡 6）

症状和原因是对应的，先取证再下结论：

- Surge 的 `dump recent` 只保留最近几百条请求。里面没有 searchtoold 记录时，先请用户在 Siri 里问一个联网问题，再立刻读一次，不要凭"没有记录"下结论。

- **能聊天、写作工具正常，但天气/新闻/知识问答报 *Something's wrong***：多半是 `searchtoold` 沙盒只允许连远端 443，连不上本机代理 `127.0.0.1:6152/6153`。请用户在 Siri 提问的同时运行（只读）：

  ```bash
  log stream --level debug --style compact --predicate 'process == "searchtoold"' \
    | grep -E 'connectx|Operation not permitted|6152|6153|RPCError'
  ```

  出现 `connectx ... Operation not permitted` 且目标是本机代理端口 → 按 docs/06 §6.4：Surge 增强模式开 + 系统代理保持开 + `skip-proxy` 加 `api-siri-prod.apple.com` + `PROCESS-NAME,searchtoold,<美国策略组>` 放在 Apple 规则集之前。

- **开了增强模式仍失败**：用 `surge-cli --raw dump recent` 看 searchtoold 的请求。若是 `17.x.x.x:443`、规则 `Apple.list`/`IP-CIDR 17.0.0.0/8`、策略 DIRECT、收到 0 字节 → 缺进程规则或顺序不对。

- **ChatGPT 扩展网页登录都成功、最后一步 *Unable to Sign In***，或 `dscacheutil -q host -a name chatgpt.com` 返回 Facebook 网段之类的地址 → DNS 污染。看 `scutil --dns` 首选 DNS；开着 Tailscale MagicDNS 时按 docs/06 §6.5 处理（`tailscale set --accept-dns=false` 由用户执行，Surge `[Host]` 把 `*.ts.net` 交给 `100.100.100.100`）。

- 用户不用 Surge：只讲原理（沙盒 443 限制、需要 TUN/虚拟网卡接管、按进程或域名把 Apple Intelligence 流量分到支持地区、避免 DNS 污染），说明作者只验证过 Surge for Mac，具体写法需要用户对照自己的工具。

- Siri 界面上的 *Server rejected RPC* 等文字不代表地区被拒，别据此让用户改账户或定位。

需要修改 Surge/Tailscale 配置时：先让用户备份配置文件，一次只改一处，改完立刻用上面的命令复核。

## 回答格式

每次回复用户都包含：
1. **现在在哪一关**（以及支撑判断的那一两行真实输出）；
2. **下一件事**（一件，带完整命令或界面路径；标明"需要你本人执行"还是"我来执行"）；
3. **做完后怎么确认**。

用户不懂技术时，用大白话解释"为什么要做这一步"，一两句即可。

## 回退

用户想恢复原厂状态时，按 docs/09 引导：先移除自动修复任务和扩展文件，再进恢复模式把启动安全恢复为**用户在关卡 1 记录的原始值**并 `csrutil enable`，回到系统后逐项核对（SIP enabled、region-info 回到 CH/A、无第三方扩展）。说明作者尚未实际执行过回退。
