#!/bin/bash
# 只读体检：Apple Intelligence / Siri AI 在国行 Mac 上的关键状态。
# 不修改任何东西。若资格文件不可读，用 sudo 运行：sudo bash check-status.sh。

PATH=/usr/bin:/bin:/usr/sbin:/sbin
ELIG=/private/var/db/eligibilityd/eligibility.plist
sec() { printf '\n== %s\n' "$1"; }
# ioreg 显示为 <4c4c2f41...>（十六进制）或 <"USA">（可打印字符串），两种都处理
propval() { local v; v=$(echo "$1" | sed -E 's/.*= <(.*)>.*/\1/'); case "$v" in \"*) echo "$v" | tr -d '"';; *) echo "$v" | xxd -r -p 2>/dev/null | tr -d '\0';; esac; }

sec "系统"
sw_vers | sed 's/^/  /'
echo "  机型: $(sysctl -n hw.model)"
up=$(( $(date +%s) - $(sysctl -n kern.boottime | sed -E 's/^\{ sec = ([0-9]+),.*/\1/') ))
echo "  内核已运行: $((up / 60)) 分钟"

sec "安全设置"
csrutil status 2>&1 | sed 's/^/  /'
if ba=$(nvram boot-args 2>/dev/null); then echo "  boot-args: $(echo "$ba" | cut -f2-)"; else echo "  boot-args: (无)"; fi

sec "设备地区（IORegistry）"
line=$(ioreg -rd1 -c IOPlatformExpertDevice)
echo "  region-info:       $(propval "$(echo "$line" | grep '"region-info"')")   （国行 CH/A，改后应为 LL/A）"
echo "  country-of-origin: $(propval "$(echo "$line" | grep '"country-of-origin"')")    （国行 CHN，改后应为 USA）"

sec "RegionSpoof 内核扩展"
if kmutil showloaded 2>/dev/null | grep -q com.local.RegionSpoof; then echo "  已加载"; else echo "  未加载"; fi
[ -d /Library/Extensions/RegionSpoof.kext ] && echo "  已安装在 /Library/Extensions" || echo "  未安装"

sec "资格（2=不符合，4=符合）"
if [ -r "$ELIG" ]; then
  for d in GREYMATTER SIRI_WITH_APP_INTENTS; do
    echo "  $d: $(plutil -extract OS_ELIGIBILITY_DOMAIN_$d.os_eligibility_answer_t raw -o - "$ELIG" 2>/dev/null || echo '?')"
  done
  echo "  资格文件更新时间: $(stat -f '%Sm' "$ELIG")"
else
  echo "  需要 sudo 才能读取：sudo bash $0"
fi
pid=$(pgrep -x eligibilityd | head -1)
[ -n "$pid" ] && echo "  eligibilityd 启动于: $(ps -o lstart= -p "$pid")"

sec "语言（系统语言与 Siri 语言须相同且为英文）"
echo "  AppleLanguages 首项: $(defaults read -g AppleLanguages 2>/dev/null | sed -n 2p | tr -d ' ",')"

sec "开机自动恢复任务"
if [ -f /Library/LaunchDaemons/com.local.ai-eligibility-fix.plist ]; then
  echo "  已安装"; [ -r /var/log/com.local.ai-eligibility-fix.log ] && tail -3 /var/log/com.local.ai-eligibility-fix.log | sed 's/^/  /'
else
  echo "  未安装（每次重启后需手动：sudo launchctl reboot userspace）"
fi

sec "网络"
echo "  首选 DNS: $(scutil --dns | awk '/nameserver\[0\]/{print $3; exit}')"
scutil --proxy | grep -E 'HTTPEnable|HTTPSEnable|SOCKSEnable' | sed 's/^ */  /'
echo
