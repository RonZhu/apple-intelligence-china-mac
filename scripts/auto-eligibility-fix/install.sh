#!/bin/bash
# 安装"开机自动恢复 Apple Intelligence 资格"。用法：sudo bash install.sh
set -eu
[ "$(id -u)" = 0 ] || { echo "请用 sudo 运行：sudo bash install.sh"; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)
L=com.local.ai-eligibility-fix

# 安装时会立即运行一次。若开机不到 15 分钟且资格未恢复，脚本会执行用户空间重启（退出所有 App）。
# 为避免安装时意外打断工作，要求开机超过 15 分钟后再安装。
boot=$(sysctl -n kern.boottime | sed -E 's/^\{ sec = ([0-9]+),.*/\1/')
up=$(( $(date +%s) - boot ))
if [ "$up" -le 900 ]; then
  echo "开机才 $((up / 60)) 分钟。请在开机 15 分钟后再安装（否则安装时可能立即触发用户空间重启）。"
  exit 1
fi

bash -n "$HERE/$L.sh"
plutil -lint "$HERE/$L.plist"

mkdir -p /usr/local/libexec
install -o root -g wheel -m 755 "$HERE/$L.sh" /usr/local/libexec/$L.sh
install -o root -g wheel -m 644 "$HERE/$L.plist" /Library/LaunchDaemons/$L.plist

launchctl bootout system/$L 2>/dev/null || true
launchctl bootstrap system /Library/LaunchDaemons/$L.plist
echo "已安装。现在运行一次检查（开机已超过 15 分钟，不会重启），约 30 秒后显示日志："
sleep 30
tail -5 /var/log/$L.log
