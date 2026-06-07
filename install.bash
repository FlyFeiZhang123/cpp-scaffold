#!/bin/bash

set -e

# 模板目录优先级：环境变量 > 默认值
BASE_SETTINGS_DIR="${BASE_SETTINGS_DIR:-$HOME/base_settings}"
if [ ! -d "$BASE_SETTINGS_DIR" ]; then
    echo "错误: 模板目录 $BASE_SETTINGS_DIR 不存在"
    exit 1
fi

# 检查是否提供了参数
if [ $# -lt 2 ]; then
    echo "用法: $0 <PROJECT_NAME> <EXECUTABLE_NAME> <NEAD_CONAN> <VSCODE/ZED>"
    echo "例如: $0 my_project my_app y z"
    exit 1
fi

PROJECT_NAME=$1
EXECUTABLE_NAME=$2
CONAN_FLAG=${3:-"n"}
EDITOR=${4:-"zed"}

echo "设置项目名称: $PROJECT_NAME"
echo "设置可执行文件名称: $EXECUTABLE_NAME"

mkdir -p include src tests third_party
if [ ! -f src/placeholder.cpp ]; then
    touch src/placeholder.cpp
fi

# 安全复制函数：目标存在则跳过，否则递归复制（目录）或普通复制（文件）
safe_cp() {
    local src="$1"
    local dst="$2"
    if [ -e "$dst" ]; then
        echo "目标 $dst 已存在，跳过复制"
        return 0
    fi
    if [ -d "$src" ]; then
        cp -r "$src" "$dst"
    else
        cp "$src" "$dst"
    fi
}

safe_cp "$BASE_SETTINGS_DIR/my_build.bash" "./my_build.bash"
safe_cp "$BASE_SETTINGS_DIR/perf_use.bash" "./perf_use.bash"
if [ "$CONAN_FLAG" = "y" ]; then
    safe_cp "$BASE_SETTINGS_DIR/conanfile.txt" "./conanfile.txt"
fi
safe_cp "$BASE_SETTINGS_DIR/example" "./example"
safe_cp "$BASE_SETTINGS_DIR/Doxyfile" "./Doxyfile"
safe_cp "$BASE_SETTINGS_DIR/tests/CMakeLists.txt" "tests/CMakeLists.txt"
safe_cp "$BASE_SETTINGS_DIR/tests/test_main.cpp" "tests/test_main.cpp"
safe_cp "$BASE_SETTINGS_DIR/.gitignore" ".gitignore"
safe_cp "$BASE_SETTINGS_DIR/README.md" "README.md"
safe_cp "$BASE_SETTINGS_DIR/.clang-format" ".clang-format" #clang-format -style=Google -dump-config > .clang-format生成后改动了缩进相关的
safe_cp "$BASE_SETTINGS_DIR/.clang-tidy" ".clang-tidy"

# 生成 CMakeLists.txt（已存在则不覆盖）
if [ -f CMakeLists.txt ]; then
    echo "CMakeLists.txt 已存在，跳过生成。如需重新生成，请先手动删除。"
else
    sed -e "s/^set(PROJECT_NAME .*)$/set(PROJECT_NAME $PROJECT_NAME)/" \
    -e "s/^[[:space:]]*set(EXECUTABLE_NAME [^)]*).*/set(EXECUTABLE_NAME $EXECUTABLE_NAME)/" \
    "$BASE_SETTINGS_DIR/CMakeLists.txt" > CMakeLists.txt
    echo "已生成 CMakeLists.txt"
fi


if [ "$EDITOR" = "zed" ]; then
    mkdir -p .zed
    if [ -f .zed/debug.json ]; then
        echo "已生成 .zed/debug.json,如需重新生成,请先手动删除。"
    else
        sed "s/__EXECUTABLE_NAME__/$EXECUTABLE_NAME/g" "$BASE_SETTINGS_DIR/.zed/debug.json" > .zed/debug.json
        echo "已生成 .zed/debug.json"
    fi
fi

if [ "$EDITOR" = "vscode" ]; then
    mkdir -p .vscode
    if [ -f .vscode/launch.json ]; then
        echo "已生成 .vscode/launch.json,如需重新生成,请先手动删除。"
    else
        sed "s/__EXECUTABLE_NAME__/$EXECUTABLE_NAME/g" "$BASE_SETTINGS_DIR/.vscode/launch.json" > .vscode/launch.json
        echo "已生成 .vscode/launch.json"
    fi
    if [ -f .vscode/settings.json ]; then
        echo "已生成 .vscode/settings.json,如需重新生成,请先手动删除。"
    else
        safe_cp "$BASE_SETTINGS_DIR/.vscode/settings.json" ".vscode/settings.json"
    fi
fi


chmod u+x ./my_build.bash ./perf_use.bash

echo "安装完成！项目已创建为 $PROJECT_NAME,可执行文件名为 $EXECUTABLE_NAME"
