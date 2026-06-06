#!/bin/bash
# 性能分析脚本，使用 perf 记录程序调用栈,权限自己调
# 用法: ./perf_use <可执行文件> [采样频率] [启动延迟]
PROG=$1
FREQ=${2:-99}
STARTUP=${3:-1}
FLAME_DIR="$HOME/FlameGraph"

[ ! -x "$PROG" ] && echo "错误: $PROG 不可执行" && exit 1

sudo pkill --exact "$(basename $PROG)" 2>/dev/null; sleep 1
rm -rf perf && mkdir -p perf

echo "启动 ${PROG}"
sudo "$PROG" &
sleep "$STARTUP"

PID=$(pgrep --exact "$(basename $PROG)")
echo "PID: $PID"

# perf 后台跑，& 不阻塞，stdin 从 /dev/null 读（不碰终端）,想要快一点的可以去掉 --call-graph dwarf,用framepointer
sudo perf record -g --call-graph dwarf -F "$FREQ" \
    -p "$PID" -o perf/perf.data < /dev/null &
PERF_PID=$!

# 复位 stdin，后面 read 不会受影响
exec < /dev/tty

# 前台等按键，perf 在后台安静采样
echo "按任意键停止采样..."
read -n 1 -s
echo ""

# 停 perf，生成 SVG
sudo kill $PERF_PID 2>/dev/null
wait $PERF_PID 2>/dev/null

echo "生成火焰图..."
sudo perf script -i perf/perf.data \
    | "$FLAME_DIR/stackcollapse-perf.pl" \
    | "$FLAME_DIR/flamegraph.pl" > perf/flamegraph.svg
echo "火焰图: perf/flamegraph.svg"

# 问是否关车
echo ""
read -p "关掉小车? [Y/n]: " ans
case $ans in
    [Nn]*) echo "PID=$PID 保留" ;;
    *) sudo kill $PID; echo "已关闭" ;;
esac
