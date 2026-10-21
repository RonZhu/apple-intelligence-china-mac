# 开机自动恢复 Apple Intelligence 资格

普通重启后 eligibilityd 会缓存国行地区，导致资格回到"不符合"。本目录的 LaunchDaemon 在每次内核开机后最多执行一次 `launchctl reboot userspace` 来恢复资格。

- 说明与安全设计：[docs/07-重启后自动恢复.md](../../docs/07-重启后自动恢复.md)
- 安装（开机 15 分钟后）：`sudo bash install.sh`
- 卸载：`sudo bash uninstall.sh`
- 应急停用：`sudo touch /var/db/com.local.ai-eligibility-fix/disabled`
- 日志：`/var/log/com.local.ai-eligibility-fix.log`

2026-10-15～10-20 在作者机器上经过三次真实重启验证：需要时自动修复一次，不需要时不动作，无重复重启。
