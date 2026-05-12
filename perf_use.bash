#!/bin/bash
# 用法: ./flame <可执行文件> [采样频率]
PROG=$1
FREQ=${2:-99}
FLAME_DIR="$HOME/FlameGraph"

if [ ! -x "$PROG" ]; then
    echo "错误: $PROG 不存在或不可执行"
    exit 1
fi

rm -rf perf
mkdir -p perf

perf record -g --call-graph dwarf -F "$FREQ" -o perf/perf.data -- "$PROG"
perf script -i perf/perf.data | "$FLAME_DIR/stackcollapse-perf.pl" | "$FLAME_DIR/flamegraph.pl" > perf/flamegraph.svg
echo "火焰图已生成: perf/flamegraph.svg"