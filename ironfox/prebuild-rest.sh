#!/usr/bin/env bash
# 运行 IronFox `prebuild.sh all` 里【除 firefox 以外】的其余目标，顺序与 all 一致。
#
# 用法：prebuild-rest.sh <IronFox 目录>
#
# 为什么要拆开跑：见 ironfox/README.md 的“补丁放在构建流程的哪一步”。
# 简单说：`prebuild.sh firefox` 负责应用 IronFox 自己的补丁；之后我们的补丁打上去；
# 其余目标里的 prepare_fenix 会把 Fenix 的 res/ 备份下来，而 build.sh 开头又会用这份备份还原 res/，
# 所以我们的补丁必须赶在备份之前打。
#
# 每个目标都由 watchdog.sh 监视（DW_STALL_SECS 等环境变量沿用工作流里的设置）。
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "用法: $0 <IronFox 目录>" >&2
  exit 2
fi
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$1"

# `prebuild.sh all` 在 firefox 之后依次准备的目标（取自 scripts/prebuild-if.sh 末尾的执行顺序）。
targets=(ac android-sdk as fenix glean microg rust uniffi)

if [ "${IRONFOX_NO_PREBUILDS:-0}" != 0 ]; then
  echo "::error::IRONFOX_NO_PREBUILDS=${IRONFOX_NO_PREBUILDS}：这时 all 还会多准备 bundletool、wasi 等目标，本脚本只按默认值 0 编写，请先改本脚本" >&2
  exit 1
fi

# 守卫：IronFox 以后如果改了 all 的组成（增加或删除了目标），这里直接报错，而不是悄悄漏跑。
# 只看 all 分支里无条件设为 1 的目标（缩进 2 个空格；NO_PREBUILDS 条件里的缩进是 4 个空格，不在内）。
script=scripts/prebuild-if.sh
expected=$(awk '
  /== .all. \]\]; then/ { f = 1; next }
  f && /^else/ { exit }
  f && /^  IRONFOX_PREPARE_[A-Z_]+=1$/ { sub(/^  IRONFOX_PREPARE_/, ""); sub(/=1$/, ""); print }
' "$script" | tr 'A-Z_' 'a-z-' | sed 's/^gecko$/firefox/' | LC_ALL=C sort)
have=$(printf '%s\n' firefox "${targets[@]}" | LC_ALL=C sort)
if [ -z "$expected" ] || [ "$expected" != "$have" ]; then
  echo "::error::IronFox 的 prebuild.sh all 包含的目标与本脚本不一致，需要同步 targets（以及工作流里先跑的 firefox）" >&2
  echo "--- IronFox 的 all ---" >&2
  echo "${expected:-<没解析出来：scripts/prebuild-if.sh 的写法可能变了>}" >&2
  echo "--- 本脚本（含 firefox）---" >&2
  echo "$have" >&2
  exit 1
fi

# shellcheck disable=SC2016  # 变量要在内层 bash 里展开，不是在这里
log_dir=$(bash -c 'source scripts/env.sh >/dev/null 2>&1 && printf %s "${IRONFOX_LOG_DIR:-}"') || true

for t in "${targets[@]}"; do
  echo "=== prebuild.sh $t ==="
  bash "$here/watchdog.sh" ./scripts/prebuild.sh "$t"
  # prebuild.sh 每次开头都会删掉上一次的 prebuild.log，这里按目标各留一份，出错时一起上传
  if [ -n "$log_dir" ] && [ -f "$log_dir/prebuild.log" ]; then
    cp -f "$log_dir/prebuild.log" "$log_dir/prebuild-$t.log"
  fi
done
echo "其余 prebuild 目标全部完成：${targets[*]}"
