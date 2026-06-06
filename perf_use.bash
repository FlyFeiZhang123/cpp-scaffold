#!/bin/bash
# 性能分析脚本，使用 perf 记录程序调用栈,权限自己调
# 用法: ./perf_use <可执行文件> [采样频率] [采样时长] [启动延迟]
PROG=$1
FREQ=${2:-99}
DURATION=${3:-30}
STARTUP=${4:-3}
FLAME_DIR="$HOME/FlameGraph"

[ ! -x "$PROG" ] && echo "错误: $PROG 不可执行" && exit 1

# 杀残留，--exact 确保只杀同名进程, basename 去掉路径 , 2>/dev/null 忽略错误
sudo pkill --exact "$(basename $PROG)" 2>/dev/null
sleep 1

rm -rf perf && mkdir -p perf

echo "启动 ${PROG}"
sudo "$PROG" &
sleep "$STARTUP"

# 用 pgrep 找到真正的程序 PID，不是 sudo 的 PID
PID=$(pgrep --exact "$(basename $PROG)")
echo "PID: $PID"
trap "sudo kill $PID 2>/dev/null; exit" INT TERM

echo "开始采样 ${DURATION}s (频率 ${FREQ}Hz)"
sudo perf record -g --call-graph dwarf -F "$FREQ" -p "$PID" -o perf/perf.data -- sleep "$DURATION"

echo ""
echo "采样完成"
sudo perf script -i perf/perf.data \
    | "$FLAME_DIR/stackcollapse-perf.pl" \
    | "$FLAME_DIR/flamegraph.pl" > perf/flamegraph.svg
echo "火焰图: perf/flamegraph.svg"

# 从 /dev/tty 读输入，不受 sudo 影响
read -p "关掉小车? [Y/n]: " ans < /dev/tty
case $ans in
    [Nn]*) echo "PID=$PID 保留" ;;
    *) sudo kill $PID; echo "已关闭" ;;
esac
