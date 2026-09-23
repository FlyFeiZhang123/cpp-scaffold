#!/bin/bash
# ============================================================
#  scaffold_lib.bash —— install.bash 与 update.bash 的共用机制
#
#  只放「两边都要用、且必须保持一致」的东西：清单怎么读、占位符名字怎么取。
#  如果不抽这一层，这两个脚本各写一份解析，过两周必然长歪
#  （README 上手工同步 doctest→gtest→uv→task_tracker 那几轮就是预演）。
#
#  用法: source "$BASE_SETTINGS_DIR/scripts/scaffold_lib.bash"
#        （要求 BASE_SETTINGS_DIR 已设置）
# ============================================================

SCAFFOLD_MANIFEST_REL="scaffold_files.list"

scaffold_manifest_path() {
    printf '%s/%s' "${BASE_SETTINGS_DIR:?BASE_SETTINGS_DIR 未设置}" "$SCAFFOLD_MANIFEST_REL"
}

# 读清单 → 四个全局数组（下标对齐）:
#   SC_CLASS  类 A/B/C      SC_FLAGS  标志串      SC_SRC  源      SC_DST  目标
scaffold_read_manifest() {
    local manifest line cls flags src dst
    manifest="$(scaffold_manifest_path)"
    if [ ! -f "$manifest" ]; then
        printf '错误: 找不到文件清单 %s\n' "$manifest" >&2
        return 1
    fi

    SC_CLASS=(); SC_FLAGS=(); SC_SRC=(); SC_DST=()
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"                              # 去注释（路径里不含 #）
        # 空行/纯注释行会读成全空，下面按空值跳过。
        # `|| true` 是给 set -e 用的：行字段不足时 read 返回非零。
        read -r cls flags src dst <<< "$line" || true
        if [ -z "${cls:-}" ] || [ -z "${src:-}" ]; then continue; fi
        SC_CLASS+=("$cls")
        SC_FLAGS+=("$flags")
        SC_SRC+=("$src")
        SC_DST+=("$dst")
    done < "$manifest"
    return 0
}

# 标志判断。会返回非零，所以只在 if / && 里用，别当独立语句跑（set -e 会炸）。
#   scaffold_flag "$flags" X
scaffold_flag() { [[ "$1" == *"$2"* ]]; }

# 从已有项目的 CMakeLists.txt 里取真名，打印 "PROJECT EXE"。
# 写法与 my_build.bash 里取 EXECUTABLE_NAME/PROJECT_NAME 的两个 sed 一致。
scaffold_project_names() {
    local f="$1" p e
    p="$(sed -n 's/^set(PROJECT_NAME \([^)]*\).*/\1/p' "$f" 2>/dev/null | head -1)"
    e="$(sed -n 's/^set(EXECUTABLE_NAME \([^)]*\).*/\1/p' "$f" 2>/dev/null | head -1)"
    printf '%s %s' "$p" "$e"
}

# 把模板里的占位符换成真名，写到 stdout（不动原文件）
scaffold_substitute() {
    sed -e "s|__PROJECT_NAME__|$1|g" \
        -e "s|__EXECUTABLE_NAME__|$2|g" \
        -- "$3"
}

# ============================================================
#  输出排版契约
#
#  没有这一层的时候，「对齐」是每个 printf 各自数空格数出来的：标签行写死
#  「两个汉字宽」，diff 正文块写死 9 个空格。两个数字之间没有关系式，于是
#  改了一个另一个必然错位 —— 标签补了宽度，正文块就掉队 2 列。
#
#  规则：全篇输出的缩进只由下面三个常量算出来，任何地方不许再写死空格。
#    SC_IND       全局缩进（标题行、收尾行）
#    SC_TAG_W     标签列宽 = 最长标签的汉字数
#    SC_TAG_COL   标签行正文的列号 —— 续行（diff 正文块）必须用同一个数
#
#  四类行：
#    标题行   scaffold_tag 之外，用 "$SC_PAD" 起头
#    标签行   scaffold_tag "覆盖" "my_build.bash"
#    续行块   ... | scaffold_body          （缩进到 SC_TAG_COL，与标签行正文同列）
#    收尾行   scaffold_note "一句话"
#
#  改标签 → 只动 SC_TAG_W；标签行和续行块一起跟着走。
#  自测里有一条断言直接量这个契约（两字标签和三字标签的正文必须同列）。
# ============================================================
SC_IND=2
SC_TAG_W=3                      # [未触碰] [已覆盖] [已新增] 是最长的几个
SC_TAG_COL=$(( SC_IND + 1 + SC_TAG_W * 2 + 1 + 1 ))
SC_PAD="$(printf '%*s' "$SC_IND" '')"
SC_BODY_PAD="$(printf '%*s' "$SC_TAG_COL" '')"
# shellcheck disable=SC2034  # 不是没用：scripts/update.bash source 本文件后用，跨文件看不出来
SC_RULE="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 标签不足 SC_TAG_W 个汉字时补空格，让正文落在同一列。
# ${#t} 在 UTF-8 locale 下数字符；退化成 C locale 时数出字节数，clamp 一下 ——
# 最坏是「不对齐」，不会比不对齐更糟。
scaffold_tag() {
    local t="$1" w=${#1}
    [ "$w" -gt "$SC_TAG_W" ] && w=$SC_TAG_W
    printf '%s[%s]%*s %s\n' "$SC_PAD" "$t" "$(( (SC_TAG_W - w) * 2 ))" '' "$2"
}
scaffold_sec()  { printf '\n── %s ── %s\n' "$1" "$2"; }
scaffold_note() { printf '%s└ %s\n' "$SC_PAD" "$1"; }
scaffold_body() { sed "s/^/$SC_BODY_PAD/"; }
