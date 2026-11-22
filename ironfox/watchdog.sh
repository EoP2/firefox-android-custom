#!/usr/bin/env bash
# 监视一条长时间运行的命令：定期打印磁盘/负载；卡住时抓取诊断信息并终止它，不再白等到 6 小时上限。
#
# 用法：watchdog.sh 命令 [参数...]
#
# “卡住”的判定：连续 DW_STALL_SECS 秒内，下面三项都没有明显变化——
#   * 整机 CPU 忙碌时间（占用不到 DW_MIN_CPU 个核）
#   * 网络收到的字节数（每个采样间隔不到 DW_MIN_RX 字节）
#   * 磁盘已用空间（每个采样间隔变化不到 DW_MIN_DISK 字节）
# 真在编译的话，CPU 一定在忙；在下载的话，网络一定在收；两者都不动，基本就是在等一个永远不会来的东西。
#
# 环境变量（都可选）：
#   DW_INTERVAL   采样间隔，秒（默认 60）
#   DW_STALL_SECS 连续多少秒没有进展就判定卡住（默认 1200）
#   DW_MIN_CPU    CPU 达到这么多个核就算有进展（默认 0.10）
#   DW_MIN_RX     每个采样间隔网络收到这么多字节就算有进展（默认 5000000）
#   DW_MIN_DISK   每个采样间隔磁盘已用量变化这么多字节就算有进展（默认 50000000）
#
# 退出码：被监视命令的退出码；判定卡住并终止时为 124。
# 被监视命令的标准输入是 /dev/null，所以任何“等待终端输入”的提问都会立刻失败，而不是一直挂着。
set -u

if [ "$#" -eq 0 ]; then
  echo "用法: $0 命令 [参数...]" >&2
  exit 2
fi

interval="${DW_INTERVAL:-60}"
stall_secs="${DW_STALL_SECS:-1200}"
min_cpu="${DW_MIN_CPU:-0.10}"
min_rx="${DW_MIN_RX:-5000000}"
min_disk="${DW_MIN_DISK:-50000000}"
hz="$(getconf CLK_TCK 2>/dev/null || echo 100)"
flag="$(mktemp -u)"
cmd_str="$*"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo -n"; fi

cpu_busy_ticks() { awk '/^cpu / {print $2+$3+$4+$7+$8+$9}' /proc/stat; }
rx_bytes() { sed 's/:/ /' /proc/net/dev | awk 'NR>2 && $1!="lo" {s+=$2} END {printf "%d\n", s}'; }
disk_used() { df -B1 --output=used / | tail -n1 | tr -d ' '; }

# 被监视命令的整个会话及其后代
related_pids() {
  ps -eo pid=,ppid=,sid= | awk -v root="$cmd" '
    { pid[NR]=$1; ppid[NR]=$2; sid[NR]=$3; n=NR }
    END {
      rel[root]=1; changed=1
      while (changed) {
        changed=0
        for (i=1; i<=n; i++)
          if (!(pid[i] in rel) && ((ppid[i] in rel) || sid[i]==root)) { rel[pid[i]]=1; changed=1 }
      }
      for (p in rel) print p
    }'
}

# 相关进程里没有子进程的那些（真正在“等”的往往是它们）
leaf_pids() {
  awk 'NR==FNR { rel[$1]=1; next }
       ($1 in rel) { mine[$1]=1; par[$2]=1 }
       END { for (p in mine) if (!(p in par)) print p }' <(related_pids) <(ps -eo pid=,ppid=)
}

# 尽力装上 py-spy（只在卡住、需要诊断时才装）。装不上就返回非 0，调用方直接跳过
ensure_pyspy() {
  command -v py-spy >/dev/null 2>&1 && return 0
  python3 -m pip install -q --user --break-system-packages py-spy >/dev/null 2>&1 || return 1
  export PATH="$HOME/.local/bin:$PATH"
  command -v py-spy >/dev/null 2>&1
}

diagnose() {
  echo "::group::卡住诊断（$(date +%T)，命令：$cmd_str）"
  echo "== 机器 =="; uptime; free -m | head -n2; df -h / | tail -n1
  echo "== 进程树（节选）=="
  # shellcheck disable=SC2009  # 要的是整棵进程树的文本视图，pgrep 给不了
  ps -eo pid,ppid,sid,stat,etime,time,wchan:22,args --forest 2>/dev/null | grep -v " ps -eo " | cut -c1-240 | tail -n 70
  echo "== 没有子进程的相关进程（通常就是卡住的那个）=="
  local pid shown=0
  for pid in $(leaf_pids); do
    [ "$pid" = "$$" ] && continue
    shown=$((shown + 1)); [ "$shown" -gt 8 ] && break
    echo "--- PID $pid"
    echo "命令行: $(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | cut -c1-300)"
    echo "状态: $(grep -m1 '^State:' "/proc/$pid/status" 2>/dev/null)   等待点(wchan): $(cat "/proc/$pid/wchan" 2>/dev/null)"
    echo "工作目录: $(readlink "/proc/$pid/cwd" 2>/dev/null)"
    echo "打开的文件/管道/连接（前 15 个）:"
    # shellcheck disable=SC2012  # 只是给人看的诊断输出
    ls -l "/proc/$pid/fd" 2>/dev/null | awk 'NR>1 {print "  " $9 " -> " $11}' | head -n 15
    if command -v strace >/dev/null 2>&1 || $SUDO apt-get install -y -qq strace >/dev/null 2>&1; then
      echo "最近 4 秒的系统调用（strace）:"
      $SUDO timeout 4 strace -f -p "$pid" -s 100 2>&1 | head -n 20 | sed 's/^/  /'
    fi
  done
  echo "== 相关 Python 进程的调用栈（py-spy；mach 卡住时通常能直接看出卡在哪一行）=="
  if ensure_pyspy; then
    local py_shown=0 exe
    for pid in $(related_pids); do
      [ "$pid" = "$$" ] && continue
      exe="$(readlink "/proc/$pid/exe" 2>/dev/null)"
      case "$(basename "${exe:-none}")" in
        python*)
          py_shown=$((py_shown + 1)); [ "$py_shown" -gt 6 ] && break
          echo "--- PID $pid  $(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | cut -c1-200)"
          $SUDO env "PATH=$PATH" py-spy dump --pid "$pid" 2>&1 | head -n 60 | sed 's/^/  /'
          ;;
      esac
    done
    [ "$py_shown" -eq 0 ] && echo "（没有找到相关的 Python 进程）"
  else
    echo "（没能装上 py-spy，跳过）"
  fi
  echo "== 网络连接 =="; $SUDO ss -tnp 2>/dev/null | head -n 25
  echo "== 内核日志里的 OOM 记录 =="; $SUDO dmesg 2>/dev/null | grep -i -E "out of memory|killed process" | tail -n 5
  echo "::endgroup::"
}

stop_tree() {
  kill -TERM -- "-$cmd" 2>/dev/null
  sleep 10
  kill -KILL -- "-$cmd" 2>/dev/null
}

monitor() {
  local last_ts now idle load
  local cpu cpu_prev rx rx_prev disk disk_prev progress d
  last_ts="$(date +%s)"
  cpu_prev="$(cpu_busy_ticks)"; rx_prev="$(rx_bytes)"; disk_prev="$(disk_used)"
  while true; do
    sleep "$interval"
    now="$(date +%s)"
    cpu="$(cpu_busy_ticks)"; rx="$(rx_bytes)"; disk="$(disk_used)"
    progress=0
    # 这个间隔里整机用了多少个核（CPU 忙碌 tick 数 / 每秒 tick 数 / 间隔秒数）
    awk -v a="$cpu" -v b="$cpu_prev" -v hz="$hz" -v iv="$interval" -v m="$min_cpu" \
      'BEGIN { exit !(((a - b) / hz / iv) >= m) }' && progress=1
    [ $((rx - rx_prev)) -ge "$min_rx" ] && progress=1
    d=$((disk - disk_prev)); d="${d#-}"
    [ "$d" -ge "$min_disk" ] && progress=1
    cpu_prev="$cpu"; rx_prev="$rx"; disk_prev="$disk"
    [ "$progress" -eq 1 ] && last_ts="$now"
    idle=$((now - last_ts))
    load="$(awk '{print $1}' /proc/loadavg)"
    printf '[监视] %s  磁盘 %s  负载 %s  已 %d 分钟无进展\n' "$(date +%T)" \
      "$(df -h / | awk 'NR==2 {print $4 " 可用(已用 " $5 ")"}')" "$load" $((idle / 60))
    if [ "$idle" -ge "$stall_secs" ]; then
      : > "$flag"
      diagnose
      stop_tree
      return
    fi
  done
}

# 在新会话里启动命令，便于整组终止。非交互 shell 里的后台进程不是进程组组长，
# 所以 setsid 不会 fork，$! 就是命令本身的 PID。
setsid "$@" < /dev/null &
cmd=$!

monitor &
mon=$!

wait "$cmd"
rc=$?
kill "$mon" 2>/dev/null
wait "$mon" 2>/dev/null

if [ -e "$flag" ]; then
  rm -f "$flag"
  echo "::error::命令连续 ${stall_secs} 秒 CPU、网络、磁盘都没有进展，判定为卡住并已终止：$cmd_str。上面【卡住诊断】里有它在等什么"
  exit 124
fi
exit "$rc"
