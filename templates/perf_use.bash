#!/bin/bash
# 用法:
#   ./perf_use <程序> [选项]          # 采样 + 生成火焰图
#   ./perf_use --serve [选项]          # 仅启动 HTTP 查看已有火焰图
set -eo pipefail

# ── 默认值 ──
DURATION=30
FREQ=99
OUT_DIR="out/perf"

# ── 帮助 ──
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat << EOF
用法: $0 [<程序>] [选项]

采样模式（默认: wrap，程序结束自动停止）:
  -t, --time <秒>   后台采样 N 秒后停止
  -m, --manual      手动模式，按 Enter 停止
  -w, --wrap        wrap 模式（默认，程序结束即停）

查看火焰图:
  --serve           在 perf/ 目录启动 HTTP 服务
  --port=<端口>     HTTP 端口（默认: 8000）
  -d, --dir <目录>  指定火焰图所在目录（配合 --serve，默认: perf）

其他:
  -f, --freq <Hz>   采样频率（默认: 99）

示例:
  $0 ./build/my_app                  # 采样 + 生成火焰图
  $0 ./build/my_app -t 30            # 后台采样 30s
  $0 ./build/my_app -m               # 手动停止
  $0 --serve                         # 启动 HTTP 查看已有火焰图
  $0 --serve --port=9000             # 指定端口
  $0 --serve -d other_perf           # 指定目录

注意:
  如果目标程序需要 root（如 pigpio），请自行用 sudo 启动程序，
  然后另开终端用 $0 -p <PID> 手动 attach 采样。
EOF
    exit 0
fi

# ── 解析参数 ──
PROG="" MODE="wrap" SERVE=false SERVE_PORT=8000
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--time)    MODE="time";   DURATION="$2"; shift 2 ;;
        -m|--manual)  MODE="manual"; shift   ;;
        -w|--wrap)    MODE="wrap";   shift   ;;
        -f|--freq)    FREQ="$2";     shift 2 ;;
        --serve)      SERVE=true;    shift   ;;
        --port=*)     SERVE_PORT="${1#*=}"; shift ;;
        -d|--dir)     OUT_DIR="$2";  shift 2 ;;
        -*)           echo "未知: $1"; exit 1 ;;
        *)            PROG="$1";     shift   ;;
    esac
done

# ═══════════════════════════════════════════════════════════
#  --serve 模式：仅启动 HTTP，不采样
# ═══════════════════════════════════════════════════════════
if $SERVE; then
    SVG="$OUT_DIR/flamegraph.svg"
    if [ ! -f "$SVG" ]; then
        echo "错误: 找不到 $SVG"
        echo "请先运行 $0 <程序> 生成火焰图"
        exit 1
    fi
    echo "serving $OUT_DIR/ → http://localhost:${SERVE_PORT}/flamegraph.svg"
    echo "按 Ctrl+C 停止"
    cd "$OUT_DIR" && python3 -m http.server "$SERVE_PORT"
    exit 0
fi

# ═══════════════════════════════════════════════════════════
#  采样模式
# ═══════════════════════════════════════════════════════════

# 未指定程序时默认用 build/app
[ -z "$PROG" ] && PROG="build/app"
[ ! -x "$PROG" ] && echo "错误: $PROG 不可执行，请先编译: ./my_build.bash" && exit 1

REAL_HOME="$(eval echo ~"${SUDO_USER:-$USER}")"
FLAME_DIR="${REAL_HOME}/FlameGraph"

# ── 检测 perf 是否需要 sudo ──
if perf record -e cpu-clock -F 99 -a -o /dev/null -- true 2>/dev/null; then
    PERF_CMD="perf"
else
    echo "perf 需要 root 权限，请求 sudo..."
    sudo -v || { echo "sudo 认证失败"; exit 1; }
    PERF_CMD="sudo perf"
fi

# ── 准备 ──
rm -rf "$OUT_DIR" && mkdir -p "$OUT_DIR"
echo "程序: $PROG | 模式: $MODE | 频率: ${FREQ}Hz"

# ── 采样 ──

if [[ "$MODE" == "wrap" ]]; then
    echo "采样中（wrap 模式，程序退出自动停止）..."
    $PERF_CMD record -g --call-graph dwarf -F "$FREQ" \
        -o "$OUT_DIR/perf.data" -- "$PROG"

elif [[ "$MODE" == "manual" ]]; then
    "$PROG" > "$OUT_DIR/program.log" 2>&1 &
    PID=$!
    sleep 1
    echo "PID: $PID | 按 Enter 停止采样..."
    $PERF_CMD record -g --call-graph dwarf -F "$FREQ" \
        -p "$PID" -o "$OUT_DIR/perf.data" < /dev/null &
    PERF_PID=$!
    read -r _
    sudo kill -INT "$PERF_PID" 2>/dev/null || true
    wait "$PERF_PID" 2>/dev/null || true
    kill "$PID" 2>/dev/null || true

else
    "$PROG" > "$OUT_DIR/program.log" 2>&1 &
    PID=$!
    sleep 1
    echo "PID: $PID | 采样 ${DURATION}s..."
    $PERF_CMD record -g --call-graph dwarf -F "$FREQ" \
        -p "$PID" -o "$OUT_DIR/perf.data" -- sleep "$DURATION"
    kill "$PID" 2>/dev/null || true
fi

# ── 生成火焰图 ──

echo "生成火焰图..."
$PERF_CMD script -i "$OUT_DIR/perf.data" \
    | "${FLAME_DIR}/stackcollapse-perf.pl" \
    | "${FLAME_DIR}/flamegraph.pl" > "$OUT_DIR/flamegraph.svg"

SVG_SIZE=$(wc -c < "$OUT_DIR/flamegraph.svg")
if [ "$SVG_SIZE" -lt 500 ]; then
    echo "错误: 火焰图为空（${SVG_SIZE} bytes），排查:"
    echo "  $PERF_CMD script -i $OUT_DIR/perf.data | head -20"
    exit 1
fi

echo "完成: $OUT_DIR/flamegraph.svg ($(du -h "$OUT_DIR/flamegraph.svg" | cut -f1))"
