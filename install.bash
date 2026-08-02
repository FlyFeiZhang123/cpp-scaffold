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

# ---- 复制模板文件（跳过已存在的）----
# 用法: copy_tpl <源> <目标> [<占位符> <替换值>]
copy_tpl() {
    local src="$1" dst="$2"

    if [ -e "$dst" ]; then
        echo "  跳过: $dst (已存在)"
        return 0
    fi

    if [ $# -ge 4 ]; then
        sed "s|$3|$4|g" "$src" > "$dst"
    elif [ -d "$src" ]; then
        cp -r "$src" "$dst"
    else
        cp "$src" "$dst"
    fi
    echo "  生成: $dst"
}

# ---- 通用模板文件 ----
for f in my_build.bash perf_use.bash bench_use.bash; do
    copy_tpl "$BASE_SETTINGS_DIR/templates/$f" "./$f"
done
[ "$CONAN_FLAG" = "y" ] && copy_tpl "$BASE_SETTINGS_DIR/templates/conanfile.txt" "./conanfile.txt"

copy_tpl "$BASE_SETTINGS_DIR/templates/example"       "./example"
copy_tpl "$BASE_SETTINGS_DIR/templates/Doxyfile"      "./Doxyfile"
[ -d "$BASE_SETTINGS_DIR/third_party" ] && copy_tpl "$BASE_SETTINGS_DIR/third_party" "./third_party"
copy_tpl "$BASE_SETTINGS_DIR/.gitignore"    "./.gitignore"
copy_tpl "$BASE_SETTINGS_DIR/.clang-format" "./.clang-format"
copy_tpl "$BASE_SETTINGS_DIR/.clang-tidy"   "./.clang-tidy"
copy_tpl "$BASE_SETTINGS_DIR/README.md"     "./README.md"
copy_tpl "$BASE_SETTINGS_DIR/templates/tests/CMakeLists.txt"  "tests/CMakeLists.txt"
copy_tpl "$BASE_SETTINGS_DIR/templates/tests/unit/test_main.cpp"      "tests/unit/test_main.cpp"
copy_tpl "$BASE_SETTINGS_DIR/templates/tests/benchmark/bench_main.cpp" "tests/benchmark/bench_main.cpp"

# ---- 示例源码 ----
copy_tpl "$BASE_SETTINGS_DIR/templates/include/calculator.h"  "include/calculator.h"
copy_tpl "$BASE_SETTINGS_DIR/templates/src/calculator.cpp" "src/calculator.cpp"

# ---- CMakeLists.txt（需替换项目名和可执行文件名）----
if [ ! -e CMakeLists.txt ]; then
    sed -e "s|__PROJECT_NAME__|$PROJECT_NAME|g" \
        -e "s|__EXECUTABLE_NAME__|$EXECUTABLE_NAME|g" \
        "$BASE_SETTINGS_DIR/templates/CMakeLists.txt" > CMakeLists.txt
    echo "  生成: CMakeLists.txt"
else
    echo "  跳过: CMakeLists.txt (已存在)"
fi

# ---- 编辑器配置 ----
if [ "$EDITOR" = "z" ]; then
    mkdir -p .zed
    copy_tpl "$BASE_SETTINGS_DIR/.zed/debug.json" ".zed/debug.json"

elif [ "$EDITOR" = "v" ]; then
    mkdir -p .vscode
    copy_tpl "$BASE_SETTINGS_DIR/.vscode/launch.json" ".vscode/launch.json"
    for f in settings.json tasks.json sudo_gdb.sh cpp.code-snippets; do
        copy_tpl "$BASE_SETTINGS_DIR/.vscode/$f" ".vscode/$f"
    done
    [ -f .vscode/sudo_gdb.sh ] && chmod +x .vscode/sudo_gdb.sh
fi

chmod u+x ./my_build.bash ./perf_use.bash
echo "✅ 项目 $PROJECT_NAME 创建完成"
