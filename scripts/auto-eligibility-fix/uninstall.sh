#!/bin/bash
# 卸载"开机自动恢复 Apple Intelligence"。用法：sudo bash uninstall.sh
set -u
[ "$(id -u)" = 0 ] || { echo "请用 sudo 运行"; exit 1; }
L=com.local.ai-eligibility-fix
launchctl bootout system/$L 2>/dev/null
rm -f /Library/LaunchDaemons/$L.plist /usr/local/libexec/$L.sh
rm -rf /var/db/$L
echo "已卸载（日志保留在 /var/log/$L.log）。以后每次重启需手动运行：sudo launchctl reboot userspace"
