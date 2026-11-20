#!/usr/bin/env bash
# 把 patches/*.patch 依次打在【IronFox 已经打完它自己补丁】的 Gecko 源码上。
#
# 用法：apply-custom-patches.sh <IronFox 目录> <补丁目录>
#
# 在工作流里的位置：`prebuild.sh firefox` 之后、`prebuild-rest.sh` 之前。
# 为什么不能更早或更晚，见 ironfox/README.md 的“补丁放在构建流程的哪一步”。
#
# 补丁路径相对 Gecko 源码根目录（mobile/android/…），按 -p1 应用；顺序是文件名的字节序（LC_ALL=C）。
#
# 严格模式（有意为之）：
#   --fuzz=0   不允许“上下文对不上也硬套”。以后 IronFox 升级导致某个补丁的位置变了，会在这里报错并指出是哪个补丁，
#              而不是悄悄套到错误的位置。
#   --forward  遇到“看起来已经应用过 / 已反向”的补丁时，不提问、不反向应用，直接按失败处理（退出码 1）。
#              不要换成 --batch：它会自动假设 -R，把已经应用的补丁悄悄撤销掉，而且退出码是 0。
#   先 dry-run，再真正应用；任何一个补丁失败就整体停下（构建在这里中止）。
#
# 环境变量 IRONFOX_GECKO（可选）：Gecko 源码目录。不设置时从 IronFox 自己的 env.sh 里取，
# 和 prebuild.sh 用的是同一个值。
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "用法: $0 <IronFox 目录> <补丁目录>" >&2
  exit 2
fi
ironfox_dir=$(cd "$1" && pwd)
patch_dir=$(cd "$2" && pwd)

if [ -z "${IRONFOX_GECKO:-}" ]; then
  # shellcheck disable=SC2016  # 变量要在内层 bash 里展开，不是在这里
  IRONFOX_GECKO=$(cd "$ironfox_dir" && bash -c 'source scripts/env.sh >/dev/null 2>&1 && printf %s "${IRONFOX_GECKO:-}"') || true
fi
if [ -z "$IRONFOX_GECKO" ] || [ ! -d "$IRONFOX_GECKO/mobile/android/fenix" ]; then
  echo "::error::找不到 Gecko 源码目录（'${IRONFOX_GECKO:-<空>}'，需要其中有 mobile/android/fenix）。请先运行 prebuild.sh firefox" >&2
  exit 1
fi

mapfile -t patches < <(find "$patch_dir" -maxdepth 1 -type f -name '*.patch' | LC_ALL=C sort)
if [ "${#patches[@]}" -eq 0 ]; then
  echo "::error::$patch_dir 里没有 .patch 文件" >&2
  exit 1
fi

cd "$IRONFOX_GECKO"
echo "Gecko 源码: $IRONFOX_GECKO"
echo "依次应用 ${#patches[@]} 个补丁（--fuzz=0，先 dry-run）："

opts=(-p1 --fuzz=0 --forward --no-backup-if-mismatch)
log=$(mktemp)
trap 'rm -f "$log"' EXIT

applied=()
for p in "${patches[@]}"; do
  name=$(basename "$p")
  # 用 -i 指定补丁文件，标准输入给 /dev/null：任何交互提问都会立刻失败，而不是挂住
  if ! patch "${opts[@]}" --dry-run -i "$p" >"$log" 2>&1 </dev/null; then
    echo "::error::补丁 $name 套不上 IronFox 打完补丁后的源码（--fuzz=0）。此前已应用：${applied[*]:-无}" >&2
    cat "$log" >&2
    echo "提示：这些补丁是针对「IronFox 打完补丁之后」的源码写的（见 ironfox/README.md）。" >&2
    echo "  * 刚升级过 IronFox / Firefox 版本：需要按新源码重新生成这个补丁。" >&2
    echo "  * 没升级：确认上一步 prebuild.sh firefox 已经成功，并且这里没有被重复运行。" >&2
    exit 1
  fi
  if ! patch "${opts[@]}" -i "$p" >"$log" 2>&1 </dev/null; then
    cat "$log" >&2
    echo "::error::补丁 $name 在 dry-run 通过后应用失败" >&2
    exit 1
  fi
  echo "  ✓ $name"
  applied+=("$name")
done

rejects=$(find mobile/android -name '*.rej' | head -5)
if [ -n "$rejects" ]; then
  echo "::error::应用后留下了 .rej 文件：" >&2
  echo "$rejects" >&2
  exit 1
fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "- 自定义补丁（打在 IronFox 打完补丁的源码上）：${applied[*]}" >> "$GITHUB_STEP_SUMMARY"
fi
echo "完成：已应用 ${#applied[@]} 个补丁"
