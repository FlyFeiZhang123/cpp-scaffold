#!/bin/bash
# ============================================================
#  update.bash —— 把已有项目更新到脚手架当前版本
#
#  ⚠ A 类是【强制覆盖】，会把同名文件替换成脚手架当前版本，你对这些文件的
#    本地改动会丢。A 类 = 脚手架自己的东西（几个 .bash、CPM.cmake、clang 配置、
#    编辑器配置、tools/），本来就不该在项目里改 —— 要改就改脚手架仓库本身，
#    下次 update 自然带过来。B 类（你的源码、示例）一个字都不碰。
#
#  CMakeLists.txt 单独处理：它既有脚手架内容又有你的项目名和自定义目标，
#  所以只做检查 —— 把模板里的 __PROJECT_NAME__ / __EXECUTABLE_NAME__ 换成
#  你项目的真名，再跟你的 CMakeLists.txt 比，只报告同不同，绝不写入。
#  其余 C 类文件（README、.gitignore、tests/ 等）一律不看不碰。
#
#  默认 dry-run：只报告打算做什么，不写一个字节。加 --apply 才动盘。
#  A 类既然会覆盖，误跑一次的代价远大于多打四个字符。
#
#  用法:
#    cd 你的项目 && updproj            # 先看（等同于本脚本，别名见 settings_use.bash）
#    cd 你的项目 && updproj --apply    # 再动
# ============================================================
set -uo pipefail

SCRIPTS_DIR="$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")"
BASE_SETTINGS_DIR="${BASE_SETTINGS_DIR:-$(dirname -- "$SCRIPTS_DIR")}"
export BASE_SETTINGS_DIR

DIFF_MAX=60          # CMakeLists.txt 最多显示多少行 diff
APPLY=0
PROJ=""

for a in "$@"; do
    case "$a" in
        --apply)   APPLY=1 ;;
        --dry-run) APPLY=0 ;;
        -h|--help|help)
            sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        -*) echo "未知参数: $a（-h 看用法）" >&2; exit 2 ;;
        *)  if [ -n "$PROJ" ]; then echo "只接受一个项目目录，多了: $a" >&2; exit 2; fi
            PROJ="$a" ;;
    esac
done
PROJ="${PROJ:-$PWD}"

[ -d "$PROJ" ] || { echo "错误: 目录不存在: $PROJ" >&2; exit 1; }
cd "$PROJ" || exit 1
PROJ="$(pwd)"

# 防呆：在没有脚手架痕迹的目录里 --apply，等于把整套模板倒进一个无关目录。
# 这里挡的是手滑（比如在家目录里跑），不是拦你的正当用法。
if [ ! -e CMakeLists.txt ] && [ ! -e my_build.bash ]; then
    printf '错误: %s 看起来不是脚手架生成的项目（既没有 CMakeLists.txt 也没有 my_build.bash）\n' "$PROJ" >&2
    printf '      要新建项目请用 newproj（install.bash）。\n' >&2
    exit 1
fi

source "$BASE_SETTINGS_DIR/scripts/scaffold_lib.bash"
scaffold_read_manifest || exit 1

# ================= 输出样式 =================
# 排版规则不在这里，在 scaffold_lib.bash：scaffold_tag / scaffold_sec /
# scaffold_note / scaffold_body 四个函数 + SC_IND / SC_TAG_W / SC_TAG_COL
# 三个常量。install.bash 将来共用同一套。
# 本文件里不许再出现写死的空格数 —— 两个地方各写一个数字，就必然错位。

# apply 模式下把动作说成完成时，免得跟 dry-run 的计划长得一模一样
T_OVER="覆盖"; T_ADD="新增"
[ "$APPLY" -eq 1 ] && { T_OVER="已覆盖"; T_ADD="已新增"; }

# 真名从项目自己的 CMakeLists.txt 里取：不换真名的话，跟模板比会满屏
# __PROJECT_NAME__ 的假差异，等于白比。
PROJ_NAME=""
EXE_NAME=""
if [ -f CMakeLists.txt ]; then
    read -r PROJ_NAME EXE_NAME <<< "$(scaffold_project_names CMakeLists.txt)"
fi

apply_one() {   # <src> <dst> <flags>   只有 --apply 会走到
    local src="$1" dst="$2" flags="$3"
    mkdir -p -- "$(dirname -- "$dst")"
    if scaffold_flag "$flags" D; then
        mkdir -p -- "$dst"
        # 合并式覆盖：同名文件盖掉，你在里头自己加的文件保留（不 rm -rf）
        cp -r -- "$src"/. "$dst"/
    else
        cp -- "$src" "$dst"
    fi
    if scaffold_flag "$flags" X; then chmod u+x -- "$dst"; fi
}

# 条件条目：install 靠命令行参数决定生不生成 N/V/Z 条目；update 没有这些参数，
# 就按「项目里已经在」推断你当初选了它。不在就不碰 —— 否则 z 编辑器的项目
# 会被硬塞一套 .vscode/。
_wanted_by_project() {   # <flags> <dst>
    local flags="$1" dst="$2"
    if [ -e "$dst" ]; then return 0; fi
    if scaffold_flag "$flags" N || scaffold_flag "$flags" V || scaffold_flag "$flags" Z; then
        return 1
    fi
    return 0
}

# ================= 头 =================
printf '%s\n' "$SC_RULE"
printf '%s● updproj · %s (%s)\n' "$SC_PAD" "${PROJ_NAME:-<未识别>}" "${EXE_NAME:-<未识别>}"
printf '%s%s\n' "$SC_PAD" "$PROJ"
if [ "$APPLY" -eq 1 ]; then
    scaffold_tag "写盘" "A 类同名文件会被强制覆盖，本地改动会丢"
else
    scaffold_tag "预览" "只看不改 · 加 --apply 才动盘"
fi
printf '%s\n' "$SC_RULE"

# ================= A 类：强制覆盖 / 补齐缺失 =================
N_ADD=0; N_OVER=0; N_SAME=0; N_SKIP=0; SKIPPED=""
scaffold_sec "A 类" "脚手架所有 · 强制覆盖 / 补齐缺失"

for i in "${!SC_SRC[@]}"; do
    [ "${SC_CLASS[$i]}" = "A" ] || continue
    flags="${SC_FLAGS[$i]}"
    src="$BASE_SETTINGS_DIR/${SC_SRC[$i]}"
    dst="${SC_DST[$i]}"

    # 条件条目被跳过要说出来：17 条清单只出现 16 条，你不该去猜少的那条
    # 是脚本漏了还是本来就不该有。顺带暴露下面那个单向陷阱。
    if ! _wanted_by_project "$flags" "$dst"; then
        N_SKIP=$((N_SKIP + 1)); SKIPPED+="${SKIPPED:+、}$dst"
        continue
    fi

    if [ ! -e "$src" ]; then
        scaffold_tag "警告" "$dst（模板里没有，清单却登记了 ${SC_SRC[$i]}）"
        continue
    fi

    # 整目录：只说「覆盖 tools/」等于没说，得指出里面动了哪个文件
    if scaffold_flag "$flags" D; then
        if [ ! -e "$dst" ]; then
            scaffold_tag "$T_ADD" "$dst/"
            N_ADD=$((N_ADD + 1))
            [ "$APPLY" -eq 1 ] && apply_one "$src" "$dst" "$flags"
            continue
        fi
        detail=""
        while IFS= read -r f; do
            rel="${f#"$src"/}"
            if [ ! -e "$dst/$rel" ]; then
                detail+="$(scaffold_tag "$T_ADD" "$dst/$rel")"$'\n'
                N_ADD=$((N_ADD + 1))
            elif ! cmp -s -- "$f" "$dst/$rel"; then
                detail+="$(scaffold_tag "$T_OVER" "$dst/$rel")"$'\n'
                N_OVER=$((N_OVER + 1))
            fi
        done < <(find "$src" -type f)
        if [ -z "$detail" ]; then
            N_SAME=$((N_SAME + 1))
        else
            printf '%s' "$detail"
            [ "$APPLY" -eq 1 ] && apply_one "$src" "$dst" "$flags"
        fi
        continue
    fi

    if [ ! -e "$dst" ]; then
        scaffold_tag "$T_ADD" "$dst"
        N_ADD=$((N_ADD + 1))
        [ "$APPLY" -eq 1 ] && apply_one "$src" "$dst" "$flags"
        continue
    fi

    differs=0
    cmp -s -- "$src" "$dst" || differs=1
    # 可执行位也算差异：bench_use.bash 历史上就靠 cp 带权限，漏过一次
    if scaffold_flag "$flags" X && [ ! -x "$dst" ]; then differs=1; fi
    if [ "$differs" -eq 1 ]; then
        scaffold_tag "$T_OVER" "$dst"
        N_OVER=$((N_OVER + 1))
        [ "$APPLY" -eq 1 ] && apply_one "$src" "$dst" "$flags"
    else
        N_SAME=$((N_SAME + 1))
    fi
done
# 只列有动作的：干净项目不该每次都刷十几行「一致」，那是噪音不是信息。
# 但一条动作都没有时，光留个 └ 挂在空列表下面，看着像脚本挂了 —— 那时
# 换成一句明确的「无需改动」，你才敢信它真的跑完了。
[ "$N_SKIP" -gt 0 ] && scaffold_tag "跳过" "$N_SKIP 条项目里没有的条件文件（$SKIPPED）"
if [ "$N_OVER" -eq 0 ] && [ "$N_ADD" -eq 0 ]; then
    scaffold_tag "一致" "$N_SAME 条都已是脚手架当前版本，没有要动的"
else
    scaffold_note "覆盖 $N_OVER 个 · 新增 $N_ADD 个 · 其余 $N_SAME 条一致"
fi

# ================= C 类里唯一要看的一个：CMakeLists.txt =================
# 只检查、只报告。你的项目名和自定义目标都在里面，脚本没资格替你决定。
scaffold_sec "C 类" "CMakeLists.txt · 只检查，绝不写入"
CMAKE_HINT=0
for i in "${!SC_SRC[@]}"; do
    [ "${SC_CLASS[$i]}" = "C" ] || continue
    scaffold_flag "${SC_FLAGS[$i]}" S || continue
    flags="${SC_FLAGS[$i]}"
    src="$BASE_SETTINGS_DIR/${SC_SRC[$i]}"
    dst="${SC_DST[$i]}"

    if [ ! -e "$dst" ]; then
        scaffold_tag "缺失" "你的项目里没有 $dst"
        scaffold_tag "提示" "newproj ${PROJ_NAME:-<项目名>} ${EXE_NAME:-<可执行名>}"
        break
    fi
    if [ -z "$PROJ_NAME" ] || [ -z "$EXE_NAME" ]; then
        scaffold_tag "跳过" "认不出 CMakeLists.txt 里的 PROJECT_NAME / EXECUTABLE_NAME"
        break
    fi

    tmp="$(mktemp)"
    scaffold_substitute "$PROJ_NAME" "$EXE_NAME" "$src" > "$tmp"
    if cmp -s -- "$tmp" "$dst"; then
        scaffold_tag "一致" "把项目名换回 $PROJ_NAME / $EXE_NAME 后，与脚手架完全相同"
        rm -f -- "$tmp"
        break
    fi

    scaffold_tag "差异" "把项目名换回 $PROJ_NAME / $EXE_NAME 后，有这些不同："
    diff -u --label "脚手架/$dst" --label "你的/$dst" "$tmp" "$dst" > "$tmp.d" 2>&1
    lines="$(wc -l < "$tmp.d")"
    if [ "$lines" -le "$DIFF_MAX" ]; then
        scaffold_body < "$tmp.d"
    else
        head -n "$DIFF_MAX" "$tmp.d" | scaffold_body
        printf '%s…（diff 共 %s 行，此处只列前 %s 行）\n' "$SC_BODY_PAD" "$lines" "$DIFF_MAX"
    fi
    rm -f -- "$tmp" "$tmp.d"
    CMAKE_HINT=1
    break
done

if [ "$CMAKE_HINT" -eq 1 ]; then
    scaffold_tag "命令" "rm CMakeLists.txt && newproj $PROJ_NAME $EXE_NAME"
    scaffold_note "想用脚手架当前版本重来就用上面这条 —— 你的自定义目标会丢，先备份"
    scaffold_note "install.bash 只补不覆盖，所以删掉这一个文件就只重生成它"
fi

# ================= 收尾 =================
n_b=0; n_c=0
for i in "${!SC_SRC[@]}"; do
    case "${SC_CLASS[$i]}" in
        B) n_b=$((n_b + 1)) ;;
        C) n_c=$((n_c + 1)) ;;
    esac
done
scaffold_sec "其余" "一切照旧"
scaffold_tag "未触碰" "B 类 $n_b 条（你的源码/示例） · C 类 $n_c 条（只有 CMakeLists.txt 会被检查）"
if [ "$APPLY" -eq 0 ]; then
    scaffold_tag "预览" "什么都没改 · 确认后加 --apply 生效"
else
    if [ "$N_OVER" -eq 0 ] && [ "$N_ADD" -eq 0 ]; then
        scaffold_tag "完成" "A 类本来就是脚手架当前版本，一个文件都不用写"
    else
        scaffold_tag "完成" "已写盘（上面标 [已覆盖] / [已新增] 的就是动过的） · C 类一个字节没写"
    fi
fi
printf '%s\n\n' "$SC_RULE"
exit 0
