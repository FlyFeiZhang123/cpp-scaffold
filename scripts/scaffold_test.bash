#!/bin/bash
# ============================================================
#  scaffold_test.bash —— 脚手架自测
#
#  测的是「脚手架本身」：install.bash 生成出来的项目能不能编、能不能过
#  ctest、软链接对不对、conan 工具链接没接上、task_tracker 能不能用、
#  update.bash 有没有守约（A 覆盖 / B 不碰 / C 只报不写 / dry-run 零写入）。
#  CI 跑它，本地也能随时跑。
#
#  为什么需要它：CI 原先直接调 cmake，绕过了 my_build.bash —— 而
#  build/app、build/test、build/bench 三个软链接正是 my_build.bash 建的。
#  后果是 build/test 从早年版起就没被生成过，一直没人发现。这里全程走
#  真实入口（install.bash → my_build.bash），并且断言产物真的存在。
#  update.bash 同理：它承诺「不写 B 类」，不拿 md5 对一遍就只是句口号。
#
#  静默失败必须靠断言兜：光「执行过」不算验证。
#
#  用法:
#    ./scripts/scaffold_test.bash            # 跑完删掉临时项目
#    ./scripts/scaffold_test.bash --keep     # 保留临时项目，便于排查
#    ./scripts/scaffold_test.bash -h
# ============================================================
set -uo pipefail

SCRIPTS_DIR="$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")"
BASE_SETTINGS_DIR="${BASE_SETTINGS_DIR:-$(dirname -- "$SCRIPTS_DIR")}"
export BASE_SETTINGS_DIR

# 排版契约（scaffold_tag / SC_TAG_COL…）在这里定义，后面直接量它。
# 顺带也验证了 lib 能被 source（update.bash / install.bash 都靠这一句）。
source "$BASE_SETTINGS_DIR/scripts/scaffold_lib.bash"

KEEP=0
case "${1:-}" in
    -h|--help|help)
        sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        exit 0 ;;
    --keep) KEEP=1 ;;
    "") ;;
    *) echo "未知参数: $1（-h 看用法）" >&2; exit 2 ;;
esac

# ---------- 结果累计（不在失败处直接退出：一次跑完，把所有问题都列出来）----------
FAILS=0
PASSES=0
ok()      { printf '  ✅ %s\n' "$1"; PASSES=$((PASSES + 1)); }
bad()     { printf '  ❌ %s\n' "$1"; FAILS=$((FAILS + 1)); }
section() { printf '\n── %s ──\n' "$1"; }

check_file() { [ -f "$1" ] && ok "$1" || bad "缺文件: $1"; }
check_exec() { [ -x "$1" ] && ok "$1 可执行" || bad "不可执行: $1"; }
check_link() { [ -L "$1" ] && [ -e "$1" ] && ok "$1 → $(readlink "$1")" || bad "软链接缺失/断链: $1"; }

WORK="$(mktemp -d)" || { echo "无法创建临时目录" >&2; exit 1; }
cleanup() {
    if [ "$KEEP" -eq 1 ]; then
        printf '\n临时项目保留在: %s\n' "$WORK"
    else
        rm -rf -- "$WORK"
    fi
}
trap cleanup EXIT

printf '脚手架自测  模板目录: %s\n' "$BASE_SETTINGS_DIR"

# ---------- 1. 模板静态检查（最便宜的一层，先挡住语法错误）----------
section "1/7 模板脚本语法"
for f in "$BASE_SETTINGS_DIR"/templates/*.bash "$BASE_SETTINGS_DIR"/templates/completions/*.bash; do
    [ -f "$f" ] || continue
    if bash -n "$f" 2>/dev/null; then ok "$(basename "$f") 语法 OK"
    else bad "$(basename "$f") 语法错误"; bash -n "$f"; fi
done
# 直接执行（别名 updproj / newproj 就是直接调它们，缺可执行位会「权限不够」）
for f in install.bash scripts/update.bash scripts/scaffold_test.bash; do
    check_exec "$BASE_SETTINGS_DIR/$f"
done

# 排版契约：正文列只由 SC_TAG_W/SC_TAG_COL 算出来，任何地方写死空格这里就露馅。
# 量法：前缀字节数 - 标签汉字数 = 列数（汉字 3 字节却只占 2 列，每字多 1 字节）。
col_of() {   # <标签> -> 该标签行正文的列号
    local ln pre
    ln="$(scaffold_tag "$1" 'X')"
    pre="${ln%X}"                       # 去掉末尾的标记，剩下「标签+补白+分隔空格」
    # 前缀字符数 = 11 - 标签字数（补白把差值顶掉了），而每个汉字占 2 列、
    # 只算 1 个字符，所以列数 = 字符数 + 标签字数。
    # 依赖 ${#} 数字符（UTF-8 locale）—— 和 scaffold_tag 自己同一个前提。
    printf '%s' "$(( ${#pre} + ${#1} ))"
}
# SC_TAG_W 是手填的「最长标签汉字数」。加一个更长的标签，scaffold_tag 会静默
# clamp 成不补白 —— 那一行就错位，而且没有任何东西会告诉你。这条把数钉死：
# 标签总表 = 脚本里的字面量（`$` 开头的排除掉，那是变量调用不是标签本身）
#           + 由变量传进去的那几个（T_OVER/T_ADD）。
_tags="$(grep -o 'scaffold_tag "[^"$]*"' "$BASE_SETTINGS_DIR/scripts/update.bash" \
         | sed 's/scaffold_tag "//; s/"$//')"
_tags="$_tags 覆盖 已覆盖 新增 已新增"
_widest=0; _over=""
for _t in $_tags; do
    [ "${#_t}" -gt "$_widest" ] && _widest=${#_t}
    [ "${#_t}" -gt "$SC_TAG_W" ] && _over="$_over [$_t]"
done
if [ -z "$_over" ]; then
    ok "SC_TAG_W=$SC_TAG_W 罩得住所有标签（最宽 $_widest 字）"
else
    bad "标签$_over 比 SC_TAG_W=$SC_TAG_W 宽，这些行的正文会错位 —— 把 SC_TAG_W 改成 $_widest"
fi

for pair in "覆盖:未触碰" "新增:已覆盖" "差异:已新增"; do
    c1="$(col_of "${pair%%:*}")"; c2="$(col_of "${pair##*:}")"
    if [ "$c1" = "$c2" ]; then
        ok "标签 [${pair%%:*}] 与 [${pair##*:}] 正文同列（第 $c1 列）"
    else
        bad "[${pair%%:*}] 在第 $c1 列、[${pair##*:}] 在第 $c2 列 —— 宽度契约破了"
    fi
done

# ---------- 2. 生成项目 ----------
section "2/7 生成项目（install.bash）"
cd "$WORK" || exit 1
if bash "$BASE_SETTINGS_DIR/install.bash" test_project test_app y v > "$WORK/gen.log" 2>&1; then
    ok "install.bash 退出 0"
else
    bad "install.bash 失败"; sed 's/^/     /' "$WORK/gen.log"
    printf '\n生成都失败了，后面没意义。\n'; exit 1
fi

section "3/7 生成物结构"
for f in CMakeLists.txt conanfile.txt .gitignore .clang-format .clang-tidy Doxyfile \
         my_build.bash perf_use.bash bench_use.bash task_tracker.bash \
         cmake/CPM.cmake cmake/Dependencies.cmake \
         tests/CMakeLists.txt tests/unit/test_main.cpp tests/benchmark/bench_main.cpp \
         include/calculator.h src/calculator.cpp example/main.cpp \
         .vscode/launch.json .vscode/tasks.json .vscode/sudo_gdb.sh; do
    check_file "$f"
done
for f in my_build.bash perf_use.bash task_tracker.bash; do check_exec "$f"; done

# 占位符必须被替换干净，否则 CMake 直接就错
if grep -q '__PROJECT_NAME__\|__EXECUTABLE_NAME__' CMakeLists.txt; then
    bad "CMakeLists.txt 里还有未替换的占位符"
else
    ok "CMakeLists.txt 占位符已替换"
fi
grep -q '^set(PROJECT_NAME test_project)' CMakeLists.txt \
    && ok "PROJECT_NAME = test_project" || bad "PROJECT_NAME 没替换对"
grep -q '^set(EXECUTABLE_NAME test_app)' CMakeLists.txt \
    && ok "EXECUTABLE_NAME = test_app" || bad "EXECUTABLE_NAME 没替换对"

# ---------- 4. 构建 + 测试（走 my_build.bash 真实入口）----------
section "4/7 构建与测试（my_build.bash test）"
if ./my_build.bash test > "$WORK/build.log" 2>&1; then
    ok "my_build.bash test 退出 0（编译 + ctest）"
else
    bad "my_build.bash test 失败"; tail -40 "$WORK/build.log" | sed 's/^/     /'
fi

# 软链接是重点：这几个曾经静默地没被创建过
check_link build/app
check_link build/test
check_link build/bench
check_link build/compile_commands.json

# 软链接能执行才算数（build/test 断链或指错是历史 bug）
if [ -x build/test ] && ./build/test > /dev/null 2>&1; then
    ok "build/test 可直接执行且用例全过"
else
    bad "build/test 执行失败（软链接目标不对，或测试没过）"
fi
if [ -x build/bench ] && ./build/bench --benchmark_min_time=0.01 > /dev/null 2>&1; then
    ok "build/bench 可直接执行"
else
    bad "build/bench 执行失败"
fi

# ctest 用例数：gtest_discover_tests 失效时数字会掉到 1（只剩 benchmark）
if grep -qE '100% tests passed' "$WORK/build.log"; then
    n="$(sed -n 's/.*out of \([0-9]*\).*/\1/p' "$WORK/build.log" | tail -1)"
    ok "ctest 全绿（${n:-?} 个用例）"
    if [ "${n:-0}" -ge 5 ]; then ok "用例数 ≥5（gtest 逐个发现生效）"
    else bad "用例数只有 ${n:-?}，gtest_discover_tests 可能失效"; fi
else
    bad "ctest 未全绿"; grep -E 'tests passed|Failed|failed' "$WORK/build.log" | tail -10 | sed 's/^/     /'
fi

# ---------- 5. Conan 集成（装了 conan 才跑）----------
# 这条路的触发条件是「装了 conan」+「项目里有 conanfile.txt」，而 conanfile.txt
# 只在 newproj 带 y 时才生成（第 2 节用的正是 y）。所以本机装了 conan 的话，第 4 节
# 那个 my_build.bash 其实已经走过这条路了 —— 这一节只是把结果验出来。CI 里单独
# 有个装 conan 的 job，就是为了让这一段真的跑起来而不是一路跳过。
section "5/7 Conan 集成"
if command -v conan >/dev/null 2>&1; then
    ok "检测到 conan（$(conan --version 2>/dev/null)）"
    # 装了却没进分支 = PATH 断了（conan 落在 ~/.local/bin，该目录未必在 PATH 上）。
    # 光看文件在不在不够，得确认分支真的进了。
    grep -q '检测到 Conan' "$WORK/build.log" \
        && ok "my_build.bash 走进了 conan 分支" \
        || bad "装了 conan 但 my_build.bash 没进 conan 分支（查 PATH）"
    # 【隐式契约】my_build.bash 第 127 行写死 build/<BuildType>/generators/：大写 Debug
    # 是 Conan cmake_layout 的拼法，与构建目录 build/debug-asan（BUILD_DIR 走了 ${VAR,,}
    # 转小写）故意不一致，全靠两边凑巧对上。
    check_file "build/Debug/generators/conan_toolchain.cmake"
    # 下面这条不是重复 —— 两条各管一头，实测过：把第 127 行改成小写之后，上面那条
    # 仍然 ✅（Conan 按自己的布局把工具链写在那儿，本来就该在），是下面这条报的红。
    #   check_file  → conan 侧布局变了 / 分支根本没进（PATH 断了文件就不会出现）
    #   下面这条    → 我们侧路径拼错了，工具链在但 CMake 没拿到
    grep -q 'CMAKE_TOOLCHAIN_FILE.*conan_toolchain' build/debug-asan/CMakeCache.txt 2>/dev/null \
        && ok "CMake 真的采用了 conan 工具链（CMakeCache 有记录）" \
        || bad "工具链生成了却没被 CMake 采用"
else
    printf '  ⏭ 跳过（本机没装 conan）—— CI 的 conan job 会跑这一段\n'
fi

# ---------- 6. 任务追踪冒烟 ----------
section "6/7 任务追踪（task_tracker.bash）"
if ./task_tracker.bash -m "冒烟任务" --tag smoke > /dev/null 2>&1; then
    ok "-m 建任务"
else
    bad "-m 建任务失败"
fi
ID="$(ls docs/tasks 2>/dev/null | head -1)"
if [ -n "$ID" ] && [ -f "docs/tasks/$ID/TASK.md" ]; then
    ok "TASK.md 落盘（$ID）"
else
    bad "TASK.md 没生成"
fi

if [ -n "$ID" ]; then
    ./task_tracker.bash tag "$ID" extra > /dev/null 2>&1 \
        && grep -q 'TAGS:.*extra' "docs/tasks/$ID/TASK.md" && ok "tag 写入 TASK.md" || bad "tag 失败"
    ./task_tracker.bash close "$ID" > /dev/null 2>&1 \
        && grep -q 'STATUS: close' "docs/tasks/$ID/TASK.md" && ok "close 生效" || bad "close 失败"
    # 不用 `cmd | grep -q`：grep -q 命中就退出，写入方吃到 SIGPIPE，
    # 在 set -o pipefail 下整条管道会被判失败（与内容无关的假失败）。
    out="$(./task_tracker.bash -l 2>/dev/null)"
    case "$out" in *'（没有符合条件的任务）'*) ok "close 后不再出现在 -l" ;;
                   *) bad "close 的任务仍出现在 -l" ;; esac
    out="$(./task_tracker.bash -t 2>/dev/null)"
    case "$out" in *'TOTAL:'*) ok "-t 统计可用" ;;
                   *) bad "-t 统计失败" ;; esac
    printf 'x\n' > smoke.txt
    ./task_tracker.bash add "$ID" smoke.txt > /dev/null 2>&1 \
        && grep -q 'ATTACH:' "docs/tasks/$ID/TASK.md" && ok "附件拷贝写入 ATTACH" || bad "add 失败"
fi

# 补全脚本能产出合法 bash（它由 --completion 动态生成）
out="$(./task_tracker.bash --completion 2>/dev/null)"
if bash -n /dev/stdin <<< "$out" 2>/dev/null; then
    ok "--completion 输出语法合法"
else
    bad "--completion 输出有语法错误"
fi

# ---------- 7. 更新机制（scripts/update.bash）----------
# 这里验的是「承诺」而不是「跑过了」：A 覆盖、B 不碰、C 只报不写、dry-run 零写入。
# 任何一条失守，用户的项目就会被静默改坏 —— 所以每条都拿 md5 对。
section "7/7 更新机制（update.bash）"
UPDATE_BASH="$BASE_SETTINGS_DIR/scripts/update.bash"
md5_of() { md5sum -- "$1" | cut -d' ' -f1; }

# 制造漂移：A 被改 / A 缺文件 / B 被改 / C 被改
echo "# 我改过的" >> perf_use.bash
rm -f Doxyfile
echo "// 我的改动" >> include/calculator.h
echo "# 我的" >> .gitignore
echo "add_library(mine)" >> CMakeLists.txt
A_BEFORE="$(md5_of perf_use.bash)"
B_BEFORE="$(md5_of include/calculator.h)"
C_BEFORE="$(md5_of .gitignore)"

bash "$UPDATE_BASH" > "$WORK/up_dry.log" 2>&1 || bad "update.bash 默认（dry-run）退出非 0"
# dry-run 是默认行为，必须一个字节都不写
[ "$(md5_of perf_use.bash)" = "$A_BEFORE" ] && ok "dry-run 没写 A 类" || bad "dry-run 竟然改了 A 类文件"
[ -f Doxyfile ] && bad "dry-run 补了缺失文件（dry-run 不该落盘）" || ok "dry-run 没落盘"
# 标签后面会补宽度空格，所以断言用 + 容忍空格数，不写死一个空格
grep -Eq '\[覆盖\] +perf_use\.bash' "$WORK/up_dry.log" && ok "dry-run 报出 A 类覆盖" || bad "dry-run 没报 A 类覆盖"
grep -Eq '\[新增\] +Doxyfile'        "$WORK/up_dry.log" && ok "dry-run 报出 A 类补齐" || bad "dry-run 没报 A 类补齐"
grep -Eq '\[差异\] +把项目名换回'    "$WORK/up_dry.log" \
    && ok "dry-run 报出 CMakeLists 差异" || bad "dry-run 没报 CMakeLists 差异"
# 对齐：标签列宽固定 3 个汉字 —— 两字标签补 2 空格、三字标签不补，
# 这样正文才都从同一列开始（[未触碰]/[已覆盖] 曾经把正文顶右 2 格）
grep -q '^  \[覆盖\]   [^ ]'   "$WORK/up_dry.log"   && ok "两字标签补足宽度（正文对齐）" || bad "两字标签没补宽度"
grep -q '^  \[未触碰\] [^ ]'   "$WORK/up_dry.log"   && ok "三字标签不补（正文对齐）"     || bad "三字标签宽度不对"
# 续行（diff 正文块）必须用同一个列号。这一段曾经写死 9 个空格，标签一补宽度
# 它就掉队 2 列 —— 这条断言就是为那次错位立的。
ncol="$(col_of 差异)"
grep -q "^$(printf '%*s' "$ncol" '')--- 脚手架/CMakeLists.txt" "$WORK/up_dry.log" \
    && ok "diff 正文块与标签行正文同列（第 $ncol 列）" || bad "diff 正文块缩进没跟标签行走"
# 清单 17 条 A 类，项目用 v 编辑器 → .zed/debug.json 该被跳过，且必须说明
grep -Fq '.zed/debug.json' "$WORK/up_dry.log" \
    && ok "跳过的条件条目被点名（不再无声少数一条）" || bad "条件条目被静默跳过，无从知道少的是哪条"
# 其余 C 类（README/.gitignore/tests/）按约定一个字都不提
grep -q '\.gitignore' "$WORK/up_dry.log" && bad "报告里提了 .gitignore（应当完全不管）" \
                                         || ok "没提 .gitignore（其余 C 类确实不管）"
bash "$UPDATE_BASH" --apply > "$WORK/up_apply.log" 2>&1 || bad "update.bash --apply 退出非 0"
cmp -s perf_use.bash "$BASE_SETTINGS_DIR/templates/perf_use.bash" \
    && ok "A 类被覆盖回模板" || bad "A 类没被覆盖"
[ -f Doxyfile ] && ok "A 类缺失文件被补上" || bad "A 类缺失文件没补"
grep -q '^  \[已覆盖\] [^ ]'   "$WORK/up_apply.log" && ok "apply 的已覆盖同样对齐"       || bad "apply 标签错位"
[ "$(md5_of include/calculator.h)" = "$B_BEFORE" ] && ok "B 类一字未动" || bad "B 类被改了（这是最严重的）"
[ "$(md5_of .gitignore)" = "$C_BEFORE" ] && ok "C 类 .gitignore 没被写入" || bad "C 类被写了"
grep -q 'add_library(mine)' CMakeLists.txt && ok "C 类 CMakeLists 保住了用户改动" || bad "CMakeLists.txt 被覆盖了"
grep -Fq 'rm CMakeLists.txt && newproj' "$WORK/up_apply.log" \
    && ok "给了 CMakeLists 的重生成提示" || bad "缺少 CMakeLists 重生成提示"

# 幂等：刚更新完再跑一次，就不该再有任何动作
bash "$UPDATE_BASH" --apply > "$WORK/up_again.log" 2>&1
grep -Fq '条都已是脚手架当前版本，没有要动的' "$WORK/up_again.log" \
    && ok "重跑幂等（一条都没动）" || bad "重跑不幂等，还在改东西"

# 目录（tools/）里的改动必须逐个点名，不能只丢一句「覆盖 tools/」
echo "x" >> tools/benchmark_tools/compare.py
rm -f tools/benchmark_tools/requirements.txt
bash "$UPDATE_BASH" > "$WORK/up_dir.log" 2>&1
grep -Eq '\[覆盖\] +tools/benchmark_tools/compare\.py' "$WORK/up_dir.log" \
    && ok "目录内被改的文件点名了" || bad "只报了「覆盖 tools/」没说哪个文件"
grep -Eq '\[新增\] +tools/benchmark_tools/requirements\.txt' "$WORK/up_dir.log" \
    && ok "目录内缺的文件点名了（且算新增不算覆盖）" || bad "目录内补齐的文件没点名"
# 目录明细跟其它 A 类行必须是同一种排版（走同一个 tag()），不能是另一种缩进
grep -q '^  \[覆盖\]   tools/' "$WORK/up_dir.log" \
    && ok "目录明细与其它标签行对齐" || bad "目录明细排版与其它行不一致"

# 防呆：无脚手架痕迹的目录里不该动手
EMPTY="$(mktemp -d)"
if bash "$UPDATE_BASH" "$EMPTY" > /dev/null 2>&1; then
    bad "在无关目录里没拦住（防呆失效）"
else
    ok "无关目录被拦住（防呆生效）"
fi
rmdir "$EMPTY"

# ---------- 结果 ----------
printf '\n════════════════════════════\n'
printf '  通过 %d   失败 %d\n' "$PASSES" "$FAILS"
printf '════════════════════════════\n'
[ "$FAILS" -eq 0 ] || exit 1
