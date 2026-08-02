#!/bin/bash
# 用法: ./bench_use.bash [选项]
# 一键跑 benchmark，自动带 PMU 硬件计数器。
# 前提:
#   1. Google Benchmark 已编译 libpfm 支持
#   2. kernel.perf_event_paranoid <= 2（当前: $(cat /proc/sys/kernel/perf_event_paranoid)）
set -eo pipefail

usage() {
    cat << 'EOF'
用法: ./bench_use.bash [选项]

运行模式:
  （默认）         表格输出，带 PMU 计数器
  --json           输出 JSON（搭配 --out 指定文件）
  --compare A B    对比两个 JSON 结果
  --list           列出所有 benchmark 名称（不运行）

选项:
  --out <文件名>   JSON 文件名（仅 --json 模式，默认: results.json）
                  输出路径固定为 out/bench/
  --bind <core>    绑核运行（如 --bind 0）
  --filter <re>    只跑匹配正则的 benchmark（如 --filter add）
  --repeat <n>     重复次数（默认由 benchmark 自动决定）

示例:
  ./bench_use.bash                             # 默认表格 + PMU 计数器
  ./bench_use.bash --json                      # 导出到 out/bench/results.json
  ./bench_use.bash --json --out v1.json        # 导出到 out/bench/v1.json
  ./bench_use.bash --bind 0                     # 绑核跑
  ./bench_use.bash --filter mul                 # 只跑包含 "mul" 的
  ./bench_use.bash --compare v1.json v2.json   # 对比 out/bench/ 下的两版

提示:
  - 当前 perf_event_paranoid = $(cat /proc/sys/kernel/perf_event_paranoid)（需 ≤2 才能读 PMU 计数器）
  - 设为 2: sudo sysctl kernel.perf_event_paranoid=2
EOF
    exit 0
}

# ── 默认值 ──
MODE="tabular"
BENCH_BIN=""
BIND_CORE=""
FILTER=""
OUT_DIR="out/bench"
FILE_NAME="results.json"
JSON_A=""
JSON_B=""

# ── 找 benchmark 二进制 ──
find_bench_bin() {
    # 优先软链接
    [ -x "build/bench" ] && echo "build/bench" && return
    # 从构建目录搜
    local exe=$(find build -maxdepth 4 -name '*_benchmark' -type f -executable 2>/dev/null | head -1)
    [ -n "$exe" ] && echo "$exe" && return
    echo ""
}

# ── 解析参数 ──
[[ "$1" == "-h" || "$1" == "--help" ]] && usage

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)       MODE="json";   shift ;;
        --compare)    MODE="compare"; JSON_A="$2"; JSON_B="$3"; shift 3 ;;
        --list)       MODE="list";   shift ;;
        --out)        FILE_NAME="$2"; shift 2 ;;
        --bind)       BIND_CORE="$2"; shift 2 ;;
        --filter)     FILTER="$2";   shift 2 ;;
        --repeat)     REPEAT="$2";   shift 2 ;;
        *)            echo "未知参数: $1"; usage ;;
    esac
done

# ── 找二进制 ──
BENCH_BIN=$(find_bench_bin)
if [ -z "$BENCH_BIN" ]; then
    echo "错误: 找不到 benchmark 二进制，请先编译: ./my_build.bash test"
    exit 1
fi
echo "benchmark 二进制: $BENCH_BIN"

# ── 检查 PMU 权限 ──
# perf_event_paranoid 控制非 root 用户能否读取 CPU 硬件计数器
PARANOID=$(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null || echo "unknown")
if [ "$PARANOID" != "unknown" ] && [ "$PARANOID" -gt 2 ] 2>/dev/null; then
    echo "⚠  kernel.perf_event_paranoid = $PARANOID（需要 ≤2，PMU 计数器将无法读取）"
    echo "   sudo sysctl kernel.perf_event_paranoid=2"
    echo ""
fi

# ── 检查 CPU 频率策略 ──
# powersave → 频率波动，Time 列不准；performance → 频率锁定，数据可复现
GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
if [ "$GOVERNOR" != "performance" ]; then
    echo "⚠  CPU governor = $GOVERNOR（建议设为 performance，否则频率波动导致数据抖动）"
    echo "   sudo cpupower frequency-set -g performance"
    echo ""
fi

# ── 检查构建类型 ──
# Debug 模式含 sanitizer + 无优化，计时无参考意义
if echo "$BENCH_BIN" | grep -qi "debug\|asan\|tsan\|ubsan"; then
    echo "⚠  检测到 Debug/Sanitizer 构建（计时偏大，仅适合验证功能）"
    echo "   建议: ./my_build.bash release no-asan && ./bench_use.bash"
    echo ""
fi

# ═══════════════════════════════════════════════════
#  --list 模式
# ═══════════════════════════════════════════════════
if [ "$MODE" = "list" ]; then
    "$BENCH_BIN" --benchmark_list_tests
    exit 0
fi

# ═══════════════════════════════════════════════════
#  --compare 模式
# ═══════════════════════════════════════════════════
if [ "$MODE" = "compare" ]; then
    # 纯文件名自动拼 out/bench/ 前缀
    [[ "$JSON_A" != */* ]] && JSON_A="$OUT_DIR/$JSON_A"
    [[ "$JSON_B" != */* ]] && JSON_B="$OUT_DIR/$JSON_B"

    COMPARE_SCRIPT="third_party/google-benchmark/tools/compare.py"
    if [ ! -f "$COMPARE_SCRIPT" ]; then
        COMPARE_SCRIPT=$(find . -path '*/benchmark/tools/compare.py' -type f 2>/dev/null | head -1)
    fi
    if [ -z "$COMPARE_SCRIPT" ] || [ ! -f "$COMPARE_SCRIPT" ]; then
        echo "错误: 找不到 compare.py"
        echo "路径: third_party/google-benchmark/tools/compare.py"
        exit 1
    fi
    [ ! -f "$JSON_A" ] && echo "错误: $JSON_A 不存在" && exit 1
    [ ! -f "$JSON_B" ] && echo "错误: $JSON_B 不存在" && exit 1
    python3 "$COMPARE_SCRIPT" benchmarks "$JSON_A" "$JSON_B"
    exit 0
fi

# ═══════════════════════════════════════════════════
#  构建命令
# ═══════════════════════════════════════════════════
CMD=("$BENCH_BIN")

# PMU 硬件计数器
[ "$MODE" != "json" ] && CMD+=(
    "--benchmark_perf_counters=CACHE-MISSES,CACHE-REFERENCES,CYCLES,BRANCH-MISSES"
    "--benchmark_counters_tabular=true"
)

# 重复次数
[ -n "$REPEAT" ] && CMD+=("--benchmark_repetitions=$REPEAT")

# 绑核
[ -n "$BIND_CORE" ] && CMD=("taskset" "-c" "$BIND_CORE" "${CMD[@]}")

# 过滤
[ -n "$FILTER" ] && CMD+=("--benchmark_filter=$FILTER")

# JSON 模式 — 先创建输出目录，避免 benchmark 写文件时报错
if [ "$MODE" = "json" ]; then
    mkdir -p "$OUT_DIR"
    CMD+=(
        "--benchmark_perf_counters=CACHE-MISSES,CACHE-REFERENCES,CYCLES,BRANCH-MISSES"
        "--benchmark_format=json"
        "--benchmark_out=$OUT_DIR/$FILE_NAME"
    )
fi

# ── 运行 ──
echo "命令: ${CMD[*]}"
echo "──────────────────────────────────────────────────"
"${CMD[@]}"

if [ "$MODE" = "json" ]; then
    echo ""
    echo "JSON 已导出到: $OUT_DIR/$FILE_NAME"
    echo "对比命令: ./bench_use.bash --compare before.json after.json"
fi
