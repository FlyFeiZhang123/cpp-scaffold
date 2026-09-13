#!/bin/bash
set -e

BASE_SETTINGS_DIR="${BASE_SETTINGS_DIR:-$HOME/cpp-scaffold}"
[ -d "$BASE_SETTINGS_DIR" ] || { echo "错误: 模板目录 $BASE_SETTINGS_DIR 不存在"; exit 1; }
[ $# -lt 2 ] && { echo "用法: $0 <项目名> <可执行文件名> [y/n=conan] [v/z=编辑器]"; echo "例如: $0 my_project my_app y v"; exit 1; }

PROJECT_NAME=$1
EXECUTABLE_NAME=$2
CONAN_FLAG=${3:-"n"}
EDITOR=${4:-"z"}

# 防止可执行文件与测试目标冲突
if [ "$EXECUTABLE_NAME" = "${PROJECT_NAME}_unit_test" ]; then
    echo "错误: 可执行文件名不能为 ${PROJECT_NAME}_unit_test（与测试目标冲突）"
    exit 1
fi

echo "项目: $PROJECT_NAME  可执行文件: $EXECUTABLE_NAME"

mkdir -p include src tests/unit tests/benchmark third_party out/logs docs

# ---- 按清单生成（清单：仓库根的 scaffold_files.list，与 scripts/update.bash 共用）----
# 本脚本只创建、从不覆盖：已存在就跳过，不看 A/B/C 类。类只影响 update 的行为。
source "$BASE_SETTINGS_DIR/scripts/scaffold_lib.bash"
scaffold_read_manifest

# 条件条目：清单里带 N / V / Z 标志的，按本次参数决定要不要生成
_want() {
    local flags="$1"
    if scaffold_flag "$flags" N && [ "$CONAN_FLAG" != "y" ]; then return 1; fi
    if scaffold_flag "$flags" V && [ "$EDITOR"     != "v" ]; then return 1; fi
    if scaffold_flag "$flags" Z && [ "$EDITOR"     != "z" ]; then return 1; fi
    return 0
}

for i in "${!SC_SRC[@]}"; do
    src="$BASE_SETTINGS_DIR/${SC_SRC[$i]}"
    dst="./${SC_DST[$i]}"
    flags="${SC_FLAGS[$i]}"

    _want "$flags" || continue

    if [ -e "$dst" ]; then
        echo "  跳过: $dst (已存在)"
        continue
    fi
    if [ ! -e "$src" ]; then
        echo "  警告: 清单登记了 ${SC_SRC[$i]}，但模板里没有这个文件"
        continue
    fi

    # 目标可能落在还没建的子目录里（cmake/、.vscode/…）：清单是按【文件】登记的，
    # 没有「整目录复制」顺带把父目录带出来这回事，所以自己补。
    mkdir -p -- "$(dirname -- "$dst")"

    if scaffold_flag "$flags" D; then
        cp -r "$src" "$dst"
    elif scaffold_flag "$flags" S; then
        scaffold_substitute "$PROJECT_NAME" "$EXECUTABLE_NAME" "$src" > "$dst"
    else
        cp "$src" "$dst"
    fi

    if scaffold_flag "$flags" X; then
        chmod u+x "$dst"
    fi
    echo "  生成: $dst"
done

echo "✅ 项目 $PROJECT_NAME 创建完成"
