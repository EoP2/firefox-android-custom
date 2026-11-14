#!/usr/bin/env bash
# 检测 IronFox 的 GeckoView 压缩包（geckoview-*.zip）是按哪个渠道编的。
#
# 用法：check-aar-channel.sh <geckoview-*.zip>
# 标准输出只有一个词：release / nightly / unknown（诊断信息都写到标准错误）。退出码恒为 0，由调用方决定怎么处理。
#
# 原理：IronFox 编译 Gecko 时，会把渠道写进 omni.ja 里的 JS（IFConstants.sys.mjs 的 IRONFOX_CHANNEL，
# 以及 GeckoView 偏好里的 browser.ironfox.const.IRONFOX_CHANNEL）。这里把 zip -> aar -> omni.ja 逐层解开，
# 只匹配“赋值”形式的写法，避免被 `IRONFOX_CHANNEL != "nightly"` 这类比较语句误导。
# 这是按源码推断写的检测，没有在真实 AAR 上验证过；找不到时输出 unknown，不会误报成某个渠道。
set -uo pipefail   # 故意不用 -e：unzip 对 omni.ja 的非标准文件头会返回 1（只是警告）
export LC_ALL=C

zip_file="${1:?用法: $0 <geckoview-*.zip>}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
log() { echo "$*" >&2; }

mkdir -p "$work/maven" "$work/omni"
if ! unzip -q -o "$zip_file" -d "$work/maven"; then
  log "无法解压 $zip_file"
  echo unknown
  exit 0
fi

mapfile -t aars < <(find "$work/maven" -type f -name '*.aar')
log "压缩包里的 AAR 数量: ${#aars[@]}"

omni_count=0
idx=0
for aar in "${aars[@]}"; do
  d="$work/aar$idx"
  mkdir -p "$d"
  unzip -q -o "$aar" -d "$d" 2>/dev/null
  while IFS= read -r omni; do
    omni_count=$((omni_count + 1))
    mkdir -p "$work/omni/$omni_count"
    unzip -q -o "$omni" -d "$work/omni/$omni_count" 2>/dev/null   # 返回 1 属正常（非标准头），内容仍会解出
  done < <(find "$d" -type f -name 'omni.ja')
  idx=$((idx + 1))
done
log "找到并解开的 omni.ja 数量: $omni_count"

channels="$(grep -rhaoE \
    -e 'IRONFOX_CHANNEL:[[:space:]]*"(nightly|release)"' \
    -e 'const\.IRONFOX_CHANNEL",[[:space:]]*"(nightly|release)"' \
    "$work/omni" 2>/dev/null | grep -oE '"(nightly|release)"$' | tr -d '"' | sort -u)"
app_ids="$(grep -rhaoE \
    -e 'IRONFOX_APP_ID:[[:space:]]*"[^"]+"' \
    -e 'const\.IRONFOX_APP_ID",[[:space:]]*"[^"]+"' \
    "$work/omni" 2>/dev/null | grep -oE '"[^"]+"$' | tr -d '"' | sort -u)"

log "检测到的渠道: ${channels:-（无）}"
log "检测到的应用 ID: ${app_ids:-（无）}"

count="$(printf '%s' "$channels" | grep -c . || true)"
if [ "$count" -eq 1 ]; then
  echo "$channels"
else
  if [ "$count" -gt 1 ]; then log "检测到互相矛盾的渠道，按 unknown 处理"; fi
  echo unknown
fi
exit 0
