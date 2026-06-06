#!/bin/bash

# 性能分析脚本，使用 perf 记录程序调用栈,权限自己调
# 用法: ./perf_use <可执行文件> [采样频率] [采样时长] [启动延迟]

PROG=$1
FREQ=${2:-99}
DURATION=${3:-30}
STARTUP=${4:-3}
FLAME_DIR="$HOME/FlameGraph"

[ ! -x "$PROG" ] && echo "错误: $PROG 不可执行" && exit 1

rm -rf perf && mkdir -p perf

echo "启动 ${PROG}"
sudo "$PROG" &
PID=$!

echo "等待 ${STARTUP}s 初始化..."
sleep "$STARTUP"

echo "开始采样 ${DURATION}s (频率 ${FREQ}Hz)"
sudo perf record -g --call-graph dwarf -F "$FREQ" -p "$PID" -o perf/perf.data -- sleep "$DURATION"

echo "采样完成！程序 (PID=$PID) 仍在运行"
sudo perf script -i perf/perf.data \
    | "$FLAME_DIR/stackcollapse-perf.pl" \
    | "$FLAME_DIR/flamegraph.pl" > perf/flamegraph.svg
echo "火焰图: perf/flamegraph.svg"
