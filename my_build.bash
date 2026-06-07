#!/bin/bash
# 用法: ./build.sh [配置...]
# 配置可选: asan, tsan, ubsan, valgrind, release
# 可组合: 如 ./build.sh asan ubsan

set -e  # 遇到错误立即退出

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    cat <<EOF
用法: $0 [选项...]
选项:
  asan, tsan, ubsan    启用对应 sanitizer
  valgrind             生成 Valgrind 兼容调试信息
  release / debug      构建类型（默认 debug)
  --exe-src=<file>     指定 example/ 下的源文件（默认 main.cpp)
EOF
    exit 0
fi

# 默认值
BUILD_DIR="build"
BUILD_TYPE="Debug"
ENABLE_ASAN=OFF
ENABLE_TSAN=OFF
ENABLE_UBSAN=OFF
USE_FOR_VALGRIND=OFF
EXECUTABLE_SRC="main.cpp"
RUN_TESTS=OFF


# 解析参数
for arg in "$@"; do
    case "$arg" in
        asan)   ENABLE_ASAN=ON ;;
        tsan)   ENABLE_TSAN=ON ;;
        ubsan)  ENABLE_UBSAN=ON ;;
        valgrind) USE_FOR_VALGRIND=ON ;;
        release) BUILD_TYPE="Release" ;;
        debug)   BUILD_TYPE="Debug" ;;
        --exe-src=*)
            EXECUTABLE_SRC="${arg#*=}"
            ;;
        test)   RUN_TESTS=ON ;;
        *)
            echo "未知参数: $arg"
            echo "支持: asan, tsan, ubsan, valgrind, release, debug, --exe-src=<file>, test"
            exit 1
            ;;
    esac
done

# 检查源文件是否存在
if [ ! -f "example/$EXECUTABLE_SRC" ]; then
    echo "错误: 源文件 example/$EXECUTABLE_SRC 不存在"
    exit 1
fi

# 检查互斥: ASan 和 TSan 不能同时启用
if [ "$ENABLE_ASAN" = "ON" ] && [ "$ENABLE_TSAN" = "ON" ]; then
    echo "错误: ASan 和 TSan 不能同时启用"
    exit 1
fi

#用这些目录的时候要注意clangd识别，不过大多数时候只要有一个项目有编译过都会产生cache,用这个cache可以用于编译的其他版本的跳转
# BUILD_DIR="build-${BUILD_TYPE,,}"
# [ "$ENABLE_ASAN" = "ON" ] && BUILD_DIR="${BUILD_DIR}-asan"
# [ "$ENABLE_TSAN" = "ON" ] && BUILD_DIR="${BUILD_DIR}-tsan"
# [ "$ENABLE_UBSAN" = "ON" ] && BUILD_DIR="${BUILD_DIR}-ubsan"
# [ "$USE_FOR_VALGRIND" = "ON" ] && BUILD_DIR="${BUILD_DIR}-valgrind"
# 创建构建目录
mkdir -p "$BUILD_DIR"
echo "构建目录: $BUILD_DIR"

# 判断是否使用 Conan
USE_CONAN=OFF
if command -v conan >/dev/null 2>&1 && [ -f conanfile.txt ]; then
    echo "检测到 Conan 和 conanfile.txt,将使用 Conan 管理依赖"
    USE_CONAN=ON

    # 生成 profile（如果还没有）
    if [ ! -f ~/.conan2/profiles/default ]; then
        conan profile detect
    fi

    # 安装依赖
    conan install . \
        -s build_type="$BUILD_TYPE" \
        --output-folder="$BUILD_DIR" \
        --build=missing

    # 设置 toolchain 文件路径
    # 尝试多个可能路径
    for path in \
        "$BUILD_DIR/build/generators/conan_toolchain.cmake" \
        "$BUILD_DIR/build/${BUILD_TYPE}/generators/conan_toolchain.cmake" \
        "$BUILD_DIR/conan_toolchain.cmake"; do
        if [ -f "$path" ]; then
            TOOLCHAIN_FILE="$path"
            break
        fi
    done
else
    echo "未检测到 Conan 或 conanfile.txt，将使用系统依赖（请确保依赖已安装）"
fi

# 配置 CMake
CMAKE_ARGS=(
    -B "$BUILD_DIR"
    -G Ninja
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
    -DENABLE_ASAN="$ENABLE_ASAN"
    -DENABLE_TSAN="$ENABLE_TSAN"
    -DENABLE_UBSAN="$ENABLE_UBSAN"
    -DUSE_FOR_VALGRIND="$USE_FOR_VALGRIND"
    -DEXECUTABLE_SRC="$EXECUTABLE_SRC"
)

# 如果使用 Conan 且 toolchain 文件存在，则添加 toolchain 参数
if [ "$USE_CONAN" = "ON" ] && [ -f "$TOOLCHAIN_FILE" ]; then
    CMAKE_ARGS+=(-DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE")
fi

if [ "$USE_CONAN" = "ON" ] && [ ! -f "$TOOLCHAIN_FILE" ]; then
    echo "警告: Conan 执行完成但未生成 toolchain 文件: $TOOLCHAIN_FILE"
    # 可选：退出或继续但标记不使用 toolchain
fi

cmake "${CMAKE_ARGS[@]}"

# 编译
ninja -C "$BUILD_DIR"

if [ "$RUN_TESTS" = "ON" ]; then
    echo "运行测试..."
    cd "$BUILD_DIR" && ctest --output-on-failure
    cd ..
fi
