#!/bin/bash
# 开机后修复 Apple Intelligence 资格（配合 RegionSpoof 使用，由 LaunchDaemon 以 root 运行）。
#
# 背景：eligibilityd 在开机第 5 秒就启动，早于 RegionSpoof 生效，缓存了国行地区，
# 资格一直是 2（不符合）；用户空间重启后新 eligibilityd 读到 LL/A，资格变 4。
#
# 规则：
#   - 每次内核启动（kern.bootsessionuuid）最多触发一次 `launchctl reboot userspace`；
#     用户空间重启不换 bootUUID，重启后本脚本再次运行时看到标记即只做复查、不再重启。
#   - 只在 RegionSpoof 已加载且 IORegistry 地区为 LL/A 时才动作。
#   - 若当前 eligibilityd 已写出两项 answer 4，则什么都不做。
#   - 内核开机超过 MAX_UPTIME 秒不动作（避免手动加载/安装时打断正在用的电脑）。
#   - 存在 $STATE_DIR/disabled 时直接退出（应急开关）。
#
# 测试：DRYRUN=1 只打印决定、不重启；STATE_DIR/ELIG/MAX_UPTIME 可用环境变量覆盖。

set -u
PATH=/usr/bin:/bin:/usr/sbin:/sbin

STATE_DIR=${STATE_DIR:-/var/db/com.local.ai-eligibility-fix}
ELIG=${ELIG:-/private/var/db/eligibilityd/eligibility.plist}
DRYRUN=${DRYRUN:-0}
MAX_UPTIME=${MAX_UPTIME:-900}
KEXT_WAIT=${KEXT_WAIT:-300}
SETTLE=${SETTLE:-20}
KEXT_ID=com.local.RegionSpoof

log() { echo "$(date '+%F %T') [$$] $*"; }

answer() { plutil -extract "$1.os_eligibility_answer_t" raw -o - "$ELIG" 2>/dev/null || echo "?"; }
answers() { echo "GREYMATTER=$(answer OS_ELIGIBILITY_DOMAIN_GREYMATTER) APP_INTENTS=$(answer OS_ELIGIBILITY_DOMAIN_SIRI_WITH_APP_INTENTS)"; }

kernel_uptime() {
  local boot
  boot=$(sysctl -n kern.boottime | sed -E 's/^\{ sec = ([0-9]+),.*/\1/')
  echo $(( $(date +%s) - boot ))
}

kext_loaded() { kextstat -l -b "$KEXT_ID" 2>/dev/null | grep -q "$KEXT_ID"; }

region_is_us() { ioreg -rd1 -c IOPlatformExpertDevice | grep '"region-info"' | grep -q '<4c4c2f41'; }

# 资格文件由"当前这个" eligibilityd 写出，且两项都是 4，才算已修好。
fresh_eligible() {
  local pid start mtime
  [ "$(answer OS_ELIGIBILITY_DOMAIN_GREYMATTER)" = 4 ] || return 1
  [ "$(answer OS_ELIGIBILITY_DOMAIN_SIRI_WITH_APP_INTENTS)" = 4 ] || return 1
  pid=$(pgrep -x eligibilityd | head -1)
  [ -n "$pid" ] || return 1
  start=$(LC_ALL=C date -j -f '%a %b %d %T %Y' "$(LC_ALL=C ps -o lstart= -p "$pid" | sed 's/  */ /g; s/^ //; s/ $//')" +%s 2>/dev/null) || return 1
  mtime=$(stat -f %m "$ELIG") || return 1
  [ "$mtime" -ge "$start" ]
}

[ -e "$STATE_DIR/disabled" ] && { log "disabled flag present, exit"; exit 0; }
mkdir -p "$STATE_DIR" && chmod 755 "$STATE_DIR"

BOOT_UUID=$(sysctl -n kern.bootsessionuuid)
MARKER="$STATE_DIR/$BOOT_UUID"
log "start boot=$BOOT_UUID uptime=$(kernel_uptime)s dryrun=$DRYRUN $(answers)"

# 已为本次内核启动做过用户空间重启：只复查并记录结果。
if [ -d "$MARKER" ]; then
  sleep 60
  log "post-fix check: $(answers) fresh_eligible=$(fresh_eligible && echo yes || echo no)"
  exit 0
fi

waited=0
until kext_loaded; do
  [ "$waited" -ge "$KEXT_WAIT" ] && { log "$KEXT_ID not loaded after ${KEXT_WAIT}s, no action"; exit 0; }
  sleep 5; waited=$((waited + 5))
done
log "$KEXT_ID loaded (waited ${waited}s)"

region_is_us || { log "region-info is not LL/A, no action"; exit 0; }

sleep "$SETTLE"
if fresh_eligible; then
  log "already eligible from current eligibilityd: $(answers), no action"
  exit 0
fi

up=$(kernel_uptime)
if [ "$up" -gt "$MAX_UPTIME" ]; then
  log "not freshly eligible ($(answers)) but uptime ${up}s > ${MAX_UPTIME}s, skip to avoid interrupting work"
  exit 0
fi

# mkdir 是原子操作：只有第一个成功创建标记的实例会去重启。
mkdir "$MARKER" 2>/dev/null || { log "marker already exists, another run handled it"; exit 0; }
date '+%F %T' > "$MARKER/triggered"
find "$STATE_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} + 2>/dev/null

if [ "$DRYRUN" = 1 ]; then
  log "DRYRUN: would run 'launchctl reboot userspace' ($(answers))"
  exit 0
fi
log "not freshly eligible ($(answers)); running launchctl reboot userspace"
launchctl reboot userspace
