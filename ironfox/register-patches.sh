#!/usr/bin/env bash
# 把 ironfox/patches/*.patch 登记进 IronFox 的补丁清单（scripts/patches.yaml）。
#
# 用法：register-patches.sh <IronFox 源码目录> <你的补丁目录>
#
# 做两件事：
#   1. 把补丁文件复制到 <IronFox>/patches/
#   2. 在 <IronFox>/scripts/patches.yaml 末尾追加条目（IronFox 只读取其中的 .patches[].file，
#      其余字段只是说明文字）。补丁按文件名字母序登记，也就是按这个顺序依次应用。
#
# 约束（来自 IronFox 的 prebuild）：
#   * 它先对【每个】补丁单独在【未打补丁的原版源码】上做 dry-run，任何一个失败就整体中止；
#     所以每个补丁都必须能独立应用于原版，不能依赖你的其它补丁（这就是 0001 与 0012 被合并的原因）。
#   * 随后再按顺序真正应用，每个补丁应用前会在当时的源码上再检查一次。
set -euo pipefail
export LC_ALL=C

if [ "$#" -ne 2 ]; then
  echo "用法: $0 <IronFox 源码目录> <你的补丁目录>" >&2
  exit 2
fi
ironfox_dir="$(cd "$1" && pwd)"
patch_dir="$(cd "$2" && pwd)"
yaml="$ironfox_dir/scripts/patches.yaml"

[ -f "$yaml" ] || { echo "::error::找不到 $yaml" >&2; exit 1; }
[ -d "$ironfox_dir/patches" ] || { echo "::error::找不到 $ironfox_dir/patches" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || [ -n "${IRONFOX_YQ:-}" ] || { echo "::error::需要 mikefarah 版 yq（用来校验 patches.yaml）" >&2; exit 1; }
YQ="${IRONFOX_YQ:-yq}"

shopt -s nullglob
files=("$patch_dir"/*.patch)
if [ "${#files[@]}" -eq 0 ]; then
  echo "::error::$patch_dir 里没有 .patch 文件" >&2
  exit 1
fi

before="$("$YQ" '.patches | length' "$yaml")"

# 文件末尾没有换行的话先补一个，避免新条目接在最后一行后面
if [ -n "$(tail -c1 "$yaml")" ]; then
  echo >> "$yaml"
fi

for p in "${files[@]}"; do
  base="$(basename "$p")"
  if [ -e "$ironfox_dir/patches/$base" ]; then
    echo "::error::补丁名和 IronFox 自带的重名：$base，请改名" >&2
    exit 1
  fi
  cp "$p" "$ironfox_dir/patches/$base"
  cat >> "$yaml" <<ENTRY

  - file: "$base"
    name: "Custom - ${base%.patch}"
    description: "Custom UI patch (${base%.patch})."
    reason: "Personal UI customization."
    effect: "Changes the Fenix / Android Components user interface."
    category: "User Interface"
ENTRY
  echo "已登记: $base"
done

# 校验：YAML 仍然能解析，条目数正好增加了 N 个，且最后 N 个文件名与我们登记的一致
after="$("$YQ" '.patches | length' "$yaml")"
expected=$((before + ${#files[@]}))
if [ "$after" -ne "$expected" ]; then
  echo "::error::patches.yaml 条目数不对：登记前 $before，登记后 $after，期望 $expected" >&2
  exit 1
fi
tail_names="$("$YQ" '.patches[].file' "$yaml" | tail -n "${#files[@]}")"
want_names="$(for p in "${files[@]}"; do basename "$p"; done)"
if [ "$tail_names" != "$want_names" ]; then
  echo "::error::patches.yaml 末尾的文件名与预期不一致" >&2
  diff <(printf '%s\n' "$want_names") <(printf '%s\n' "$tail_names") >&2 || true
  exit 1
fi
echo "patches.yaml：$before -> $after 个补丁（新增 ${#files[@]} 个）"
