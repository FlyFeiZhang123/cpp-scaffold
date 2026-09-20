#!/usr/bin/env bash
#
# tools/tidy_fix.bash —— 批量套用本项目的命名规范 (.clang-tidy)
# 用法和正则例子见 -h。撤销: git checkout -- <文件>

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
    cat <<'EOF'
用法:
  tools/tidy_fix.bash <路径正则>            只报告，不改（默认，安全）
  tools/tidy_fix.bash -w <路径正则>         先列出会被改的文件 → 确认 → 才改
  tools/tidy_fix.bash -w --all <路径正则>   连 modernize/bugprone 一起改

路径正则 —— 拿去匹配编译数据库里的 .cpp 路径，不用写全路径：
  'example/main'     挑一个编译单元
  'tests/'           挑一个目录（命中该目录下所有 .cpp）
  '\.cpp$'           全部编译单元
  'condition_var'    头文件名也行 —— 见下面「没命中」那条

正则命中编译单元(.cpp) → 改这些编译单元（连带它 include 到的头文件）
正则没命中 → 当成文件名，跑项目全部编译单元，但只改这个文件

撤销: git checkout -- <文件>
EOF
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

WRITE=0
ALL=0
PAT=""
while [ $# -gt 0 ]; do
    case "$1" in
        -w|--write) WRITE=1; shift ;;
        --all)      ALL=1; shift ;;
        -h|--help)  usage; exit 0 ;;
        -*)         echo "未知选项: $1" >&2; usage >&2; exit 2 ;;
        *)          PAT="$1"; shift ;;
    esac
done

if [ -z "$PAT" ]; then
    echo "❌ 必须给一个路径正则。" >&2
    echo >&2
    usage >&2
    exit 2
fi

[ -f build/compile_commands.json ] || { echo "❌ 没有 build/compile_commands.json —— 先编译一次。" >&2; exit 1; }

# ── 项目自己的编译单元 ──────────────────────────────────────────────
# 数据库里 28 个文件有 24 个是第三方的（GoogleTest / Benchmark，在 ~/.cache/cpm
# 下，项目外面）。只取项目内的 —— 这就是唯一的安全边界，后面所有动作都只在这个
# 集合里挑，永远碰不到第三方。
mapfile -t CUS < <(python3 -c "
import json
r = '$ROOT/'
for f in sorted({e['file'] for e in json.load(open('build/compile_commands.json'))}):
    if f.startswith(r):
        print(f[len(r):])
")

# ── 正则命中的编译单元？没命中就当文件名 ────────────────────────────
SEL=()
for c in "${CUS[@]}"; do
    if [[ "$c" =~ $PAT ]]; then SEL+=("$c"); fi
done

LF=()
if [ ${#SEL[@]} -eq 0 ]; then
    # 头文件不在编译数据库里（数据库只记编译器真正编译的 .cpp）。不猜 include
    # 关系 —— 按成熟做法跑全部编译单元，用 -line-filter 把范围锁到你要的文件。
    # -line-filter 的 name 是精确路径（不吃正则），裸文件名和相对路径都行。
    mapfile -t NAMED < <(find . -type f -not -path './build/*' -not -path './.git/*' \
                             -not -path './out/*' -printf '%P\n' | grep -E "$PAT" || true)
    if [ ${#NAMED[@]} -eq 0 ]; then
        echo "❌ 没匹配到: $PAT" >&2
        echo >&2
        echo "   正则是拿去匹配编译单元（编译数据库里的 .cpp）的，只有这 ${#CUS[@]} 个:" >&2
        printf '     %s\n' "${CUS[@]}" >&2
        echo >&2
        echo "   例子:" >&2
        echo "     'example/main'     挑一个编译单元" >&2
        echo "     'tests/'           挑一个目录（命中该目录下所有 .cpp）" >&2
        echo "     '\.cpp\$'          全部编译单元" >&2
        echo "     'condition_var'    头文件名也行 —— 没命中 .cpp 时会当成文件名" >&2
        exit 1
    fi
    echo "ℹ️  没命中编译单元，当成文件名：跑全部 ${#CUS[@]} 个编译单元，只改 ${NAMED[*]}"
    SEL=("${CUS[@]}")
    LF=("-line-filter=$(python3 -c '
import json, sys
print(json.dumps([{"name": n, "lines": [[1, 1 << 30]]} for n in sys.argv[1:]]))
' "${NAMED[@]}")")
fi

# ── 组装参数 ────────────────────────────────────────────────────────
# HeaderFilterRegex 在 .clang-tidy 里，clang-tidy 自己会读，不用传。
# -checks 的值以 '-' 开头，必须用 = 形式，否则 argparse 当成选项。
ARGS=(-p build -j "$(nproc)" "${LF[@]}")
[ "$ALL" -eq 0 ] && ARGS+=("-checks=-*,readability-identifier-naming")

if [ "$WRITE" -eq 0 ]; then
    echo "══ 只报告（加 -w 才真改）══"
    run-clang-tidy "${ARGS[@]}" "${SEL[@]}"
    exit 0
fi

# ── 写入：先导出修复单，列清单，确认，再应用 ────────────────────────
# 不用 run-clang-tidy -fix：并行跑时，两个编译单元都想改同一个共享头文件会打架。
# 导出成补丁再统一应用是标准做法。
FIX="$TMP/fixes"
mkdir -p "$FIX"
echo "① 分析中（只导出补丁，还没碰你的文件）..."
if ! run-clang-tidy "${ARGS[@]}" -export-fixes "$FIX" "${SEL[@]}" >"$TMP/log" 2>&1; then
    echo "❌ clang-tidy 执行失败:" >&2
    tail -20 "$TMP/log" >&2
    exit 1
fi

# 从输出里直接抠文件名，不解析导出的 YAML（它的 Replacements 嵌在
# DiagnosticMessage 内部，换个版本就可能变，太脆）
LIST="$(grep -oE '^/*[^:]+:[0-9]+:[0-9]+: warning:' "$TMP/log" | cut -d: -f1 | sort | uniq -c | sort -rn || true)"
if [ -z "$LIST" ]; then
    echo "✅ 没有需要修的地方。文件未改动。"
    exit 0
fi

echo
echo "② 以下文件将被修改（这是全部，没有别的）:"
echo "$LIST"
echo

APPLY="$(command -v clang-apply-replacements \
      || command -v clang-apply-replacements-18 || true)"
[ -n "$APPLY" ] || { echo "❌ 找不到 clang-apply-replacements。" >&2; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || echo "⚠️  不是 git 仓库 —— 改错了没得退，先自己备份。"
printf "   应用？[y/N] "
read -r ans
case "$ans" in [yY]*) ;; *) echo "已取消，文件未改动。"; exit 1 ;; esac

echo "③ 应用中 + clang-format ..."
"$APPLY" --format --style=file "$FIX" >/dev/null
echo "✅ 完成。git diff 看改了什么。"
