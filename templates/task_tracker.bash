#!/usr/bin/env bash
# ============================================================
#  task_tracker.bash —— 极简任务追踪（单文件，无外部依赖）
#
#  数据目录:  <脚本所在目录>/docs/tasks/
#  任务 ID:   YYYYMMDD-HHMMSS（本地时间），撞名自动加 -1
#  任务文件:  docs/tasks/<id>/TASK.md
#  标签说明:  docs/tasks/tags（可选，一行一个「标签 说明」）
#
#  注意 docs/ 也是 Doxygen 的输出目录（见 Doxyfile 的 OUTPUT_DIRECTORY）。
#  两者互不干扰（Doxygen 只写 html/ 和 latex/），但别整个 rm -rf docs。
#
#  设计参考 tsoding/tatr — https://github.com/tsoding/tatr
# ============================================================
set -uo pipefail

TASKS_DIRNAME="docs/tasks"
IMG_EXTS=" png jpg jpeg gif webp bmp svg avif tif tiff "

# 项目根 = 脚本所在目录。相对路径一律以它为基准。
ROOT="$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")"
TASKS_DIR="$ROOT/$TASKS_DIRNAME"

declare -A TAG_DESC=()          # 标签 → 说明，来自 $TASKS_DIR/tags

die() { printf '错误: %s\n' "$*" >&2; exit 1; }
is_image() { [[ "$IMG_EXTS" == *" $1 "* ]]; }
task_md_path() { printf '%s/%s/TASK.md' "$TASKS_DIR" "$1"; }

# 生成新 ID：本地时间戳，撞名就加 -1 -2 ...
new_huid() {
    local base; base="$(date +%Y%m%d-%H%M%S)"
    local id="$base" n=0
    while [[ -e "$TASKS_DIR/$id" ]]; do n=$((n + 1)); id="$base-$n"; done
    printf '%s' "$id"
}

# 简写 ID → 完整 ID。唯一匹配就打印；不唯一把候选打到 stderr；找不到用 $2 当提示。
# 失败时 exit 非零，所以调用方要写 id="$(resolve_id x)" || exit 1
#
# 匹配优先「后缀」：这样 051534 命中 20260913-051534，
# 不会被同一秒的 20260913-051534-1 搅成歧义。
resolve_id() {
    local want="$1" hint="${2:-}" d base
    local -a suffix=() sub=() hits=()

    [[ -d "$TASKS_DIR/$want" ]] && { printf '%s' "$want"; return 0; }
    for d in "$TASKS_DIR"/*/; do
        [[ -d "$d" ]] || continue
        base="${d%/}"; base="${base##*/}"
        [[ "$base" == *"$want"* ]] || continue
        [[ "$base" == *"$want" ]] && suffix+=("$base") || sub+=("$base")
    done
    hits=("${suffix[@]}")
    [[ ${#hits[@]} -gt 0 ]] || hits=("${sub[@]}")

    case ${#hits[@]} in
        0) die "${hint:-找不到任务: $want}" ;;
        1) printf '%s' "${hits[0]}" ;;
        *) printf '任务 ID 不唯一: %s\n' "$want" >&2
           printf '  %s\n' "${hits[@]}" >&2
           printf '请多写几位。\n' >&2
           exit 1 ;;
    esac
}

# ---------- 读 TASK.md ----------
# 状态只有 open / close 两个值。分类是标签的事，别往这儿塞。
task_status() {
    local s
    s="$(grep -m1 '^- STATUS:' "$1" 2>/dev/null | sed 's/^- STATUS:[[:space:]]*//')"
    s="$(printf '%s' "$s" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
    [[ "$s" == closed || "$s" == done ]] && s="close"
    printf '%s' "${s:-open}"
}

task_title() {
    local t; t="$(sed -n '1s/^#[[:space:]]*//p' "$1")"
    printf '%s' "${t:-（无标题）}"
}

task_attach_count() { grep -c '^- \(ATTACH\|LINK\):' "$1" 2>/dev/null || true; }

# 追加一行；已经有一模一样的一行了就跳过（$3 是打印用的文字）。
# 覆盖场景会走到这里：add -f 用同一个文件名重新拷一遍，不该记第二笔账。
add_line() {
    if grep -Fxq -- "$2" "$1" 2>/dev/null; then printf '%s（TASK.md 里已记过，跳过）\n' "$3"; return 0; fi
    printf '%s\n' "$2" >> "$1" || die "无法写入: $1"
    printf '%s\n' "$3"
}

# 生成 markdown 链接；图片用 ![]()，其它用 []()
md_link() {
    local ext="${1##*.}"; ext="${ext,,}"
    local label="${1//]/\\]}" dest="${2// /%20}"
    if is_image "$ext"; then printf '![%s](%s)' "$label" "$dest"
    else printf '[%s](%s)' "$label" "$dest"; fi
}

# ---------- 标签 ----------
# 拆分规则抄 tatr 的 parse_tags：按「空白或逗号」切，连续分隔符当一个。
# 所以 "bug,ui"、"bug ui"、"bug, ui" 等价；标签本身不能含空格和逗号。
norm_tags() { tr ',[:space:]' '\n' | sed '/^$/d'; }
split_tags() { printf '%s\n' "$@" | norm_tags; }
task_tags() { grep -m1 '^- TAGS:' "$1" 2>/dev/null | sed 's/^- TAGS:[[:space:]]*//' | norm_tags; }

# 写回 TASK.md 时那一行的样子（和 tatr 的 render 一致：逗号分隔、不带空格）
render_tags_line() {
    [[ $# -eq 0 ]] && { printf -- '- TAGS:'; return 0; }
    local IFS=,; printf -- '- TAGS: %s' "$*"
}

tags_display() { [[ $# -eq 0 ]] || { local IFS=,; printf '[%s]' "$*"; }; }

# 任务是否带着全部这几个标签（--tag a,b 是「与」，越筛越窄）。
task_has_tags() {
    local f="$1"; shift
    local -a have=(); local t x
    while IFS= read -r t; do have+=("$t"); done < <(task_tags "$f")
    for x in "$@"; do
        local hit=0
        for t in "${have[@]}"; do [[ "$t" == "$x" ]] && { hit=1; break; }; done
        [[ "$hit" -eq 1 ]] || return 1
    done
    return 0
}

# 标签写回 TASK.md：有 TAGS 行就整行替换，没有就插到 DATE 后面；
# 连 DATE 都没有（手搓的文件）就退而插在标题后面。
# 用 awk 重写整份再 cat 覆盖回去（而不是 mv），原文件的权限和属主才不变。
write_tags() {
    local f="$1"; shift
    local line tmp; line="$(render_tags_line "$@")"
    tmp="$(mktemp)" || die "mktemp 失败"

    # 注意 awk 不认 `--`（mawk 会把它当成文件名），这里不能写 -- "$f"。
    # 路径由 task_md_path 拼出来，不会有前导减号。
    awk -v t="$line" '
        /^- TAGS:/ { if (!d) { print t; d = 1 } ; next }
        { print }
        /^- DATE:/ { if (!d) { print t; d = 1 } }
    ' "$f" > "$tmp" || { rm -f -- "$tmp"; die "无法写入: $f"; }

    if ! grep -q '^- TAGS:' -- "$tmp"; then
        awk -v t="$line" 'NR == 1 { print; print t; next } { print }' "$tmp" > "$tmp.2" \
            && mv -f -- "$tmp.2" "$tmp" \
            || { rm -f -- "$tmp" "$tmp.2"; die "无法写入: $f"; }
    fi

    cat -- "$tmp" > "$f" || { rm -f -- "$tmp"; die "无法写入: $f"; }
    rm -f -- "$tmp"
}

# 读 $TASKS_DIR/tags —— 一行一个「标签 + 说明」，之间用空白或逗号隔开。
# 没有这个文件不是错误，什么都不做。
load_tag_desc() {
    local f="$TASKS_DIR/tags" line tag
    [[ -f "$f" ]] || return 0
    while IFS= read -r line || [[ -n "$line" ]]; do
        tag="${line%%[[:space:],]*}"                    # 第一个空白或逗号之前
        [[ -n "$tag" ]] || continue
        [[ -n "${TAG_DESC[$tag]:-}" ]] \
            && printf '%s: 警告: 标签说明重复定义，后一条覆盖前一条: %s\n' "$f" "$tag" >&2
        TAG_DESC[$tag]="$(printf '%s' "${line#"$tag"}" | sed 's/^[[:space:],]*//; s/[[:space:]]*$//')"
    done < "$f"
}

# ---------- 新建 / 追记 ----------
create_task() {
    local text="$1"; shift
    local id dir
    [[ -n "$text" ]] || die "说明不能为空"
    id="$(new_huid)"; dir="$TASKS_DIR/$id"
    mkdir -p -- "$dir" || die "无法创建: $dir"
    {
        printf '# %s\n\n- STATUS: open\n- DATE: %s\n' "$text" "$(date '+%Y-%m-%d %H:%M:%S')"
        if [[ $# -gt 0 ]]; then printf '%s\n' "$(render_tags_line "$@")"; fi
    } > "$dir/TASK.md" || die "无法写入: $dir/TASK.md"
    [[ $# -gt 0 ]] && text="$(tags_display "$@")  $text"      # 两格，和没标签时对齐
    printf '新建 %s  %s\n' "$id" "$text"
}

append_note() {
    local f; f="$(task_md_path "$1")"
    [[ -n "$2" ]] || die "说明不能为空"
    [[ -f "$f" ]] || die "任务没有 TASK.md: $1"
    printf '\n---\n\n%s\n' "$2" >> "$f" || die "无法写入: $f"
    printf '追加 %s  %s\n' "$1" "$2"
}

# ---------- add：附件 ----------
add_file() {
    local id="$1" abs="$2" link="$3" force="$4"
    local dir; dir="$TASKS_DIR/$id"
    local base; base="$(basename -- "$abs")"

    if [[ "$link" -eq 1 ]]; then
        # 只记路径不拷贝。路径一律写成相对 TASK.md 所在目录 ——
        # realpath --relative-to 对任意两个路径都算得出来，包括项目外的。
        # 千万别退回绝对路径：markdown 里以 / 开头是被按「工作区根」（VS Code）
        # 或「站点根」（GitHub）解析的，不是文件系统根，写出来必是破图。
        local rel
        rel="$(realpath --relative-to="$dir" -- "$abs" 2>/dev/null)" || rel=""
        [[ -n "$rel" ]] || rel="$abs"      # 跨挂载点等极端情况才用绝对路径
        add_line "$dir/TASK.md" "- LINK: $(md_link "$base" "$rel")" "链接 $rel"

        # 项目外的文件，预览器通常只允许加载工作区内的资源，多半显示不出来。
        # 与其让你对着破图标猜，不如当场说清楚。
        if [[ "$abs" != "$ROOT"/* ]]; then
            printf '  注意: %s 在项目外（%s），markdown 预览多半显示不出来\n' "$rel" "$ROOT"
            printf '        要能显示请去掉 --link（会拷进任务目录）\n'
        fi
        return 0
    fi

    # 拷贝进任务文件夹，同名自动加 -1 后缀，绝不覆盖（除非 -f）
    local stem="$base" ext=""
    if [[ "$base" == *.* && "$base" != .* ]]; then stem="${base%.*}"; ext=".${base##*.}"; fi
    local target="$dir/$base" n
    if [[ -e "$target" && "$force" -eq 0 ]]; then
        n=1
        while [[ -e "$dir/$stem-$n$ext" ]]; do n=$((n + 1)); done
        base="$stem-$n$ext"; target="$dir/$base"
    fi
    cp -p -- "$abs" "$target" || die "拷贝失败: $abs"
    add_line "$dir/TASK.md" "- ATTACH: $(md_link "$base" "$base")" "拷贝 $base"
}

add_path() {
    local id="$1" raw="$2" link="$3" recursive="$4" force="$5"
    local abs f
    if [[ "$raw" == /* ]]; then abs="$(realpath -m -- "$raw")"
    else abs="$(realpath -m -- "$ROOT/$raw")"; fi

    if [[ -d "$abs" ]]; then
        [[ "$recursive" -eq 1 ]] || die "是目录: $raw（要整个目录加进来请加 -r）"
        while IFS= read -r -d '' f; do add_file "$id" "$f" "$link" "$force"; done \
            < <(find "$abs" -type f -print0)
        return 0
    fi
    [[ -f "$abs" ]] || die "找不到文件: $raw"
    add_file "$id" "$abs" "$link" "$force"
}

# 用法: add <id> [选项] <路径...>
# 第一个参数【必须】是 id —— 于是只需要一段循环。
# 早先是「选项区 + 路径区」两段扫描：选项区认 -f/-r，路径区只认 --link/--copy，
# 导致 add <id> -f x 会莫名报「路径不能以 '-' 开头」，而 add -f <id> x 却是好的。
# 合并成一段后所有选项走同一个 case，位置无关，这种不一致自然消失。
cmd_add() {
    local link=0 recursive=0 force=0 id
    [[ $# -gt 0 ]] || die '用法: add <id> [选项] <路径...>（-h 看选项）'

    case "$1" in
        -*) die "add: 第一个参数必须是任务 ID，选项写在它后面（-h 看用法）" ;;
    esac
    id="$(resolve_id "$1")" || exit 1
    shift
    [[ $# -gt 0 ]] || die 'add: 没有给文件'

    # 选项都是「粘性」的：--link/--copy 切模式，-r/-f 开关，对【其后】的路径生效
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --link)         link=1; shift ;;
            --copy)         link=0; shift ;;
            -r|--recursive) recursive=1; shift ;;
            -f|--force)     force=1; shift ;;
            --)             shift
                            while [[ $# -gt 0 ]]; do add_path "$id" "$1" "$link" "$recursive" "$force"; shift; done ;;
            -*)             die "add: 未知选项: $1（想当文件名请先写 --）" ;;
            *)              add_path "$id" "$1" "$link" "$recursive" "$force"; shift ;;
        esac
    done
}

# ---------- 列表 ----------
# mode: open（没做完的，也就是不是 close 的） | all
# 后面跟的标签（可以多个）是额外的过滤条件，全都要满足。
cmd_list() {
    local mode="$1"; shift
    local -a ftags=("$@")
    local d base f st ti n tg
    local -a lines=()

    if [[ ! -d "$TASKS_DIR" ]]; then printf '（还没有任务）\n'; return 0; fi

    for d in "$TASKS_DIR"/*/; do
        [[ -d "$d" ]] || continue
        base="${d%/}"; base="${base##*/}"
        f="$d/TASK.md"; [[ -f "$f" ]] || continue

        st="$(task_status "$f")"
        case "$mode" in
            all)  ;;
            *)    [[ "$st" != close ]] || continue ;;
        esac

        [[ ${#ftags[@]} -eq 0 ]] || task_has_tags "$f" "${ftags[@]}" || continue

        ti="$(task_title "$f")"
        n="$(task_attach_count "$f")"
        tg="$(task_tags "$f")"; tg="${tg//$'\n'/,}"
        # 字段分隔符必须是非空白字符：\t 属于 IFS 空白，空字段变成连续两个 \t
        # 会被 read 折叠成一个，整行字段左移（没标签的任务就会串位）。
        lines+=("$(printf '%s\x1f%s\x1f%s\x1f%s\x1f%s' "$base" "$st" "$tg" "$ti" "$n")")
    done

    if [[ ${#lines[@]} -eq 0 ]]; then printf '（没有符合条件的任务）\n'; return 0; fi

    while IFS=$'\x1f' read -r base st tg ti n; do
        [[ -n "$tg" ]] && tg="[$tg]"
        if [[ "$n" -gt 0 ]]; then
            printf '%-17s %-6s %-12s %s  [%s]\n' "$base" "$st" "$tg" "$ti" "$n"
        else
            printf '%-17s %-6s %-12s %s\n' "$base" "$st" "$tg" "$ti"
        fi
    done < <(printf '%s\n' "${lines[@]}" | sort -r)
}

# -l / -a 的参数：只认 --tag，别的一律报错（免得把标签当成模式名吞掉）。
cmd_list_args() {
    local mode="$1"; shift
    local -a raw=() flat=(); local t
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tag|-T) shift
                      [[ $# -gt 0 ]] || die "--tag 后面要给标签"
                      raw+=("$1"); shift ;;
            --tag=*)  raw+=("${1#--tag=}"); shift ;;
            -*)       die "未知选项: $1（-h 看用法）" ;;
            *)        die "不接受参数: $1（要按标签筛请写 --tag $1）" ;;
        esac
    done
    if [[ ${#raw[@]} -gt 0 ]]; then
        while IFS= read -r t; do flat+=("$t"); done < <(split_tags "${raw[@]}")
    fi
    cmd_list "$mode" ${flat[@]+"${flat[@]}"}
}

# ---------- 改状态 ----------
cmd_set_status() {
    local want="$1"; shift
    [[ $# -eq 1 ]] || die "用法: $want <id>"
    local id f
    id="$(resolve_id "$1")" || exit 1
    f="$(task_md_path "$id")"
    [[ -f "$f" ]] || die "任务没有 TASK.md: $id"

    if grep -q '^- STATUS:' "$f"; then
        sed -i "s/^- STATUS:.*/- STATUS: $want/" -- "$f" || die "写入失败: $f"
    else
        sed -i "1a - STATUS: $want" -- "$f" || die "写入失败: $f"
    fi
    printf '%s  →  %s\n' "$id" "$want"
}

# ---------- 改标签 ----------
# mode: add | del
cmd_tag() {
    local mode="$1"; shift
    local verb=tag; [[ "$mode" == add ]] || verb=untag
    [[ $# -ge 2 ]] || die "用法: $verb <id> <标签...>"

    local id f; id="$(resolve_id "$1")" || exit 1; shift
    f="$(task_md_path "$id")"; [[ -f "$f" ]] || die "任务没有 TASK.md: $id"

    local -a want=() cur=() out=()
    local t c hit
    while IFS= read -r t; do want+=("$t"); done < <(split_tags "$@")
    [[ ${#want[@]} -gt 0 ]] || die "$verb: 标签不能为空"
    while IFS= read -r t; do cur+=("$t"); done < <(task_tags "$f")

    if [[ "$mode" == add ]]; then
        out=("${cur[@]}")
        for t in "${want[@]}"; do
            hit=0; for c in "${out[@]}"; do [[ "$c" == "$t" ]] && hit=1; done
            [[ $hit -eq 0 ]] && out+=("$t")             # 没有才加，天然去重
        done
    else
        for c in "${cur[@]}"; do
            hit=0; for t in "${want[@]}"; do [[ "$c" == "$t" ]] && hit=1; done
            [[ $hit -eq 0 ]] && out+=("$c")             # 命中就丢掉
        done
    fi

    # 标签不含空格，所以直接拼成字符串比较就够了
    [[ "${cur[*]}" == "${out[*]}" ]] \
        && { printf '%s 标签没变: %s\n' "$id" "$(tags_display "${cur[@]}")"; return 0; }

    write_tags "$f" "${out[@]}"
    if [[ ${#out[@]} -gt 0 ]]; then printf '%s  %s\n' "$id" "$(tags_display "${out[@]}")"
    else printf '%s  （标签删空了）\n' "$id"; fi
}

# ---------- 统计 ----------
# filter: all | undone | close
cmd_stat() {
    local filter="$1" d base f st t n
    local total=0 untagged=0
    local -A cnt=()
    local -a order=() rows=()

    if [[ ! -d "$TASKS_DIR" ]]; then printf '（还没有任务）\n'; return 0; fi

    for d in "$TASKS_DIR"/*/; do
        [[ -d "$d" ]] || continue
        base="${d%/}"; base="${base##*/}"
        f="$d/TASK.md"; [[ -f "$f" ]] || continue

        st="$(task_status "$f")"
        case "$filter" in
            close)  [[ "$st" == close ]] || continue ;;
            undone) [[ "$st" != close ]] || continue ;;
        esac

        total=$((total + 1)); n=0
        while IFS= read -r t; do
            [[ -n "${cnt[$t]:-}" ]] || order+=("$t")    # 记住首次出现的次序
            cnt[$t]=$(( ${cnt[$t]:-0} + 1 ))
            n=$((n + 1))
        done < <(task_tags "$f")
        [[ "$n" -eq 0 ]] && untagged=$((untagged + 1))
    done

    local label="全部"
    [[ "$filter" == close ]]  && label="close"
    [[ "$filter" == undone ]] && label="open"

    printf 'STATUS:   %s\nTOTAL:    %d\n' "$label" "$total"
    [[ "$untagged" -gt 0 ]] && printf 'UNTAGGED: %d\n' "$untagged"
    [[ ${#order[@]} -gt 0 ]] || return 0

    printf 'TAGGED:\n'
    local maxw=0 tag num desc
    for t in "${order[@]}"; do
        [[ "${#t}" -gt "$maxw" ]] && maxw="${#t}"
        rows+=("$(printf '%010d\t%s' "${cnt[$t]}" "$t")")
    done
    # 计数降序；计数相同按标签名升序，保证每次跑出来顺序一样
    while IFS=$'\t' read -r num tag; do
        desc="${TAG_DESC[$tag]:-}"
        printf '    %*s => %3d%s\n' "$maxw" "$tag" "$((10#$num))" "${desc:+ - $desc}"
    done < <(printf '%s\n' "${rows[@]}" | sort -t$'\t' -k1,1nr -k2,2)
}

cmd_stat_args() {
    local filter=all
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--close)  filter=close;  shift ;;
            -u|--undone) filter=undone; shift ;;
            -*) die "-t: 未知选项: $1（-h 看用法）" ;;
            *)  die "-t 不接受参数: $1" ;;
        esac
    done
    load_tag_desc
    cmd_stat "$filter"
}

# ---------- 用法 ----------
cmd_usage() {
    cat <<EOF
task_tracker.bash —— 极简任务追踪（数据在 $TASKS_DIRNAME/）

用法:
  task_tracker.bash -m "说明" [--tag a,b]      新建任务（可带标签）
  task_tracker.bash -m <id> "说明"             给已有任务追加说明
  task_tracker.bash -l [--tag a,b]             列出没做完的
  task_tracker.bash -a [--tag a,b]             列出全部
  task_tracker.bash -t [-c|-u]                 统计（默认全算）
  task_tracker.bash add <id> [选项] <路径...>   添加附件（第一个参数必须是 id）
  task_tracker.bash tag <id> <标签...>         加标签
  task_tracker.bash untag <id> <标签...>       去标签
  task_tracker.bash open|close <id>            改状态
  task_tracker.bash -h                         帮助

add 选项:
  --link            其后的文件只记路径，不拷贝
                    路径写成相对 TASK.md 的，原文件一挪链接就断
                    项目外的文件会有警告 —— 预览器不放行工作区外的资源，
                    多半只显示破图标，要能显示就用默认的拷贝模式
  --copy            切回拷贝（默认）
  -r, --recursive   允许传目录
  -f, --force       同名时覆盖（默认自动加 -1 后缀）
  --                其后全当路径，不再识别开关

-t 选项:
  -c, --close       只统计 close 的
  -u, --undone      只统计没完成的（open）

状态:  open（在做） / close（已完成）—— 只有这两个
       状态管「进度」，一个任务同时只能有一个，所以别往这儿塞分类
标签:  TASK.md 里一行 "- TAGS: a,b"；按「空白或逗号」拆分，
      所以 "a,b" 和 "a b" 等价，标签本身不能含空格和逗号
       标签管「分类」，可以有任意多个，和状态互不干涉：
       close 一个任务只改状态，标签原样留着
       --tag 是「与」：--tag a,b 要两个都有，越筛越窄
ID:    YYYYMMDD-HHMMSS（本地时间），可以只写唯一的一段，如 121503

说明:
  项目根 = 本脚本所在目录；相对路径一律以项目根为基准
  （即使从子目录里调用也是，和 shell 直觉不同）
  任务 ID 和 TASK.md 里的 DATE 都用本地时间，跟你墙上的钟一致
  add 往 TASK.md 追加链接行：拷贝的写 ATTACH，只记路径的写 LINK，
  同一行记过就不再记（add -f 覆盖同一个文件时不会记两笔）
  标签说明写在 $TASKS_DIRNAME/tags 里，一行一个「标签 说明」，
  -t 统计时把说明缀在计数后面

约定（脚本本身不认识，纯粹是给标签起名字):
  scope  长期方向。它是个标签，不是状态 ——
         「做完了但方向还在」的任务可以 close 掉但留着 scope 标签，
         以后 -a --tag scope 照样能全捞出来
         例:  tag <id> scope      -a --tag scope      untag <id> scope

补全: 由 cpp-scaffold 的全局补全提供，source ~/.bashrc 后自动生效
      （--completion 是给它调用的，不用手动跑）
EOF
}

cmd_completion() {
    local body
    body="$(cat <<'EOS'
# task_tracker.bash 的补全 —— 由 cpp-scaffold 的全局补全用 --completion 调起来
_task_tracker_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local sub="${COMP_WORDS[1]:-}"
    local dir="__TASKS_DIR__"

    # 列任务 ID，$1 = 已敲进去的一段，按「子串」过滤。
    # 不能交给 compgen -W —— 它只做前缀匹配，而 ID 是以年份开头的，
    # 敲 0516<Tab> 会一个都补不出来。
    _tt_ids() {
        local want="${1:-}" x
        [[ -d "$dir" ]] || return 0
        for x in "$dir"/*/; do
            [[ -d "$x" ]] || continue
            x="${x%/}"; x="${x##*/}"
            [[ -z "$want" || "$x" == *"$want"* ]] && printf '%s\n' "$x"
        done
        return 0        # 必须显式成功：上面那个 && 在最后一个目录不匹配时返回 1，
                        # 会让调用处的 `A && B || C` 误判成失败
    }
    # 文件路径补全。两个坑，别改回去：
    #  - 调用处必须用 mapfile 收，不能写 COMPREPLY=( $(...) )——命令替换不加引号
    #    会按 IFS 再切一次，「my file.png」会被劈成 my 和 file.png 两个候选。
    #  - compopt -o filenames 必须在【主 shell】里调（调用处紧挨着写），不能塞进这个
    #    函数：调用处是 mapfile ... < <(_tt_files)，进程替换会 fork 子 shell，
    #    compopt 的状态改动出不去，等于没写。少了它 readline 就不知道这是文件名，
    #    于是目录补全不插 '/' 反而补个空格（敲 sub<Tab> 得到 "sub "），
    #    含空格的路径也不转义。
    _tt_files() { compgen -f -- "$cur"; return 0; }
    # 已有的标签名，取自各任务的 TAGS 行（tags 说明文件里定义的也算）。
    # 去重是必须的 —— 一个标签在好几个任务上用过，菜单里就会列好几遍。
    _tt_tags() {
        local x
        { [[ -d "$dir" ]] && for x in "$dir"/*/TASK.md; do
              [[ -f "$x" ]] || continue
              sed -n 's/^- TAGS:[[:space:]]*//p' "$x" | tr ',' '\n'
          done
          [[ -f "$dir/tags" ]] && sed 's/[[:space:]].*//' "$dir/tags"
        } 2>/dev/null | awk 'NF && !seen[$0]++'
        return 0
    }

    if [[ "$COMP_CWORD" -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "add tag untag open close -m -l -a -t -h --completion" -- "$cur") )
        return 0
    fi

    case "$sub" in
        tag|untag)
            # 先补 ID，之后补已有标签名（也可以直接敲个新的）
            if [[ "$COMP_CWORD" -eq 2 ]]; then COMPREPLY=( $(_tt_ids "$cur") )
            else COMPREPLY=( $(compgen -W "$(_tt_tags)" -- "$cur") ); fi
            ;;
        open|close)
            # 第一个位置补 ID，之后没什么可补的
            if [[ "$COMP_CWORD" -eq 2 ]]; then COMPREPLY=( $(_tt_ids "$cur") )
            else COMPREPLY=(); fi
            ;;
        -l|-a)
            case "${COMP_WORDS[COMP_CWORD-1]}" in
                --tag|-T) COMPREPLY=( $(compgen -W "$(_tt_tags)" -- "$cur") ) ;;
                *) [[ "$cur" == -* ]] && COMPREPLY=( $(compgen -W "--tag" -- "$cur") )
                   COMPREPLY+=( $(compgen -W "$(_tt_tags)" -- "$cur") ) ;;
            esac
            ;;
        add)
            # 第一个参数固定是 id —— 不用再扫描前面出现过什么
            if [[ "$COMP_CWORD" -eq 2 ]]; then COMPREPLY=( $(_tt_ids "$cur") )
            elif [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "--link --copy -r --recursive -f --force --" -- "$cur") )
            else compopt -o filenames 2>/dev/null || true
                 mapfile -t COMPREPLY < <(_tt_files); fi
            ;;
        -m)
            case "${COMP_WORDS[COMP_CWORD-1]}" in
                --tag|-T) COMPREPLY=() ;;                      # 标签，自由文本
                *) if [[ "$cur" == -* ]]; then
                       COMPREPLY=( $(compgen -W "--tag -T --" -- "$cur") )
                   elif [[ "$COMP_CWORD" -eq 2 ]]; then COMPREPLY=( $(_tt_ids "$cur") )
                   else compopt -o filenames 2>/dev/null || true
                        mapfile -t COMPREPLY < <(_tt_files); fi ;;
            esac
            ;;
        *) compopt -o filenames 2>/dev/null || true
           mapfile -t COMPREPLY < <(_tt_files) ;;
    esac
}
complete -F _task_tracker_complete task_tracker.bash ./task_tracker.bash
EOS
)"
    printf '%s\n' "${body//__TASKS_DIR__/$TASKS_DIR}"
}

# ---------- 入口 ----------
cmd_message() {
    local -a pos=() tagarg=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tag|-T) shift
                      [[ $# -gt 0 ]] || die "--tag 后面要给标签"
                      tagarg+=("$1"); shift ;;
            --tag=*)  tagarg+=("${1#--tag=}"); shift ;;
            --)       shift; while [[ $# -gt 0 ]]; do pos+=("$1"); shift; done ;;
            -*)       die "-m: 未知选项: $1（-h 看用法）" ;;
            *)        pos+=("$1"); shift ;;
        esac
    done

    local id t
    local -a tags=()
    if [[ ${#tagarg[@]} -gt 0 ]]; then
        while IFS= read -r t; do tags+=("$t"); done < <(split_tags "${tagarg[@]}")
    fi

    if [[ ${#pos[@]} -eq 1 ]]; then
        create_task "${pos[0]}" ${tags[@]+"${tags[@]}"}
    elif [[ ${#pos[@]} -eq 2 ]]; then
        [[ ${#tags[@]} -eq 0 ]] || die "附加说明时不能给 --tag；给已有任务加标签请用: tag <id> <标签...>"
        id="$(resolve_id "${pos[0]}" '第一个参数不是任务 ID。
  如果这是想新建任务，请只给一段文字并加引号：-m "你的说明"')" || exit 1
        append_note "$id" "${pos[1]}"
    else
        die '用法: -m "说明" [--tag a,b]   或   -m <id> "说明"'
    fi
}

main() {
    case "${1:-}" in
        ""|-h|--help|help) cmd_usage ;;
        --completion)      cmd_completion ;;
        -m)                shift; cmd_message "$@" ;;
        -l)                shift; cmd_list_args open "$@" ;;
        -a)                shift; cmd_list_args all  "$@" ;;
        -t|--stat)         shift; cmd_stat_args "$@" ;;
        add)               shift; cmd_add "$@" ;;
        tag)               shift; cmd_tag add "$@" ;;
        untag)             shift; cmd_tag del "$@" ;;
        open|close)        local st="$1"; shift; cmd_set_status "$st" "$@" ;;
        *)                 die "未知参数: $1（-h 看用法）" ;;
    esac
}

main "$@"
