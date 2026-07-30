#!/bin/bash
# 用法: ./my_build.bash [选项...]
# 示例:
#   ./my_build.bash                        # 默认: Debug + ASAN + perf
#   ./my_build.bash release                # Release 构建
#   ./my_build.bash asan perf              # 显式开启
#   ./my_build.bash tsan no-perf           # TSan + 关帧指针
#   ./my_build.bash no-asan no-perf lto    # 纯 Release 无 sanitizer
#   ./my_build.bash --exe-src=other.cpp     # 切换编译目标（CMake缓存记录，后续无需再传）
#   ./my_build.bash --exe-src=placeholder.cpp test
#   ./my_build.bash no-march               # WSL2 用
set -e

usage() {
    cat << EOF
用法: $0 [选项...]

Sanitizers:
  asan, tsan, ubsan     启用对应 sanitizer
  no-asan, no-tsan      关闭（默认 ASAN=ON）

性能分析:
  perf / no-perf         帧指针开关（默认 perf=ON）
  march / no-march       -march=native 开关（默认 ON，WSL2 用 no-march）

优化:
  lto                    启用链接时优化（默认 OFF）

构建:
  release / debug        构建类型（默认 Debug）
  --exe-src=<file>       切换 example/ 下编译源文件，CMake 缓存自动持久化
  test                   编译后运行测试
  --which, -w            查看当前软链接指向哪个构建变体
EOF
    exit 0
}

[[ "$1" == "-h" || "$1" == "--help" ]] && usage

# ===== 默认值 =====
BUILD_TYPE="Debug"
ENABLE_ASAN=ON
ENABLE_TSAN=OFF
ENABLE_UBSAN=OFF
ENABLE_PERF=ON
USE_MARCH_NATIVE=ON
ENABLE_LTO=OFF
USE_FOR_VALGRIND=OFF
EXECUTABLE_SRC="main.cpp"     # 仅首次构建的默认值，之后由 CMake 缓存决定
_EXPLICIT_EXE_SRC=0
RUN_TESTS=OFF

# ===== 解析参数 =====
for arg in "$@"; do
    case "$arg" in
        asan)       ENABLE_ASAN=ON     ;;
        no-asan)    ENABLE_ASAN=OFF    ;;
        tsan)       ENABLE_TSAN=ON     ;;
        no-tsan)    ENABLE_TSAN=OFF    ;;
        ubsan)      ENABLE_UBSAN=ON    ;;
        valgrind)   USE_FOR_VALGRIND=ON ;;
        perf)       ENABLE_PERF=ON     ;;
        no-perf)    ENABLE_PERF=OFF    ;;
        march)      USE_MARCH_NATIVE=ON ;;
        no-march)   USE_MARCH_NATIVE=OFF ;;
        lto)        ENABLE_LTO=ON      ;;
        release)    BUILD_TYPE="Release" ;;
        debug)      BUILD_TYPE="Debug"   ;;
        test)       RUN_TESTS=ON       ;;
        --exe-src=*) EXECUTABLE_SRC="${arg#*=}"; _EXPLICIT_EXE_SRC=1 ;;
        --which|-w)
            EXECUTABLE_NAME=$(sed -n 's/^set(EXECUTABLE_NAME \([^)]*\).*/\1/p' CMakeLists.txt | head -1)
            LINK="build/${EXECUTABLE_NAME}"
            if [ -L "$LINK" ]; then
                echo "build/${EXECUTABLE_NAME} → $(readlink "$LINK")"
            else
                echo "build/${EXECUTABLE_NAME} 不存在（请先构建）"
            fi
            exit 0
            ;;
        *)
            echo "未知参数: $arg"; usage ;;
    esac
done

# ===== 校验 =====
[ ! -f "example/$EXECUTABLE_SRC" ] && echo "错误: example/$EXECUTABLE_SRC 不存在" && exit 1
[ "$ENABLE_ASAN" = "ON" ] && [ "$ENABLE_TSAN" = "ON" ] && echo "错误: ASan 和 TSan 互斥" && exit 1

# ===== 构建目录 =====
BUILD_DIR="build/${BUILD_TYPE,,}"
[ "$ENABLE_ASAN" = "ON" ]  && BUILD_DIR="${BUILD_DIR}-asan"
[ "$ENABLE_TSAN" = "ON" ]  && BUILD_DIR="${BUILD_DIR}-tsan"
[ "$ENABLE_UBSAN" = "ON" ] && BUILD_DIR="${BUILD_DIR}-ubsan"

# ===== 输出配置摘要 =====
HEAD="──"
_info() { printf "  %-16s %s\n" "$1" "$2"; }
echo "$HEAD Build Config $HEAD"
_info "Build type"   "$BUILD_TYPE"
_info "Build dir"    "$BUILD_DIR"
_info "ASAN"         "$ENABLE_ASAN"
_info "TSAN"         "$ENABLE_TSAN"
_info "UBSAN"        "$ENABLE_UBSAN"
_info "Perf (fp)"    "$ENABLE_PERF"
_info "march=native" "$USE_MARCH_NATIVE"
_info "LTO"          "$ENABLE_LTO"
_info "CCache"       "$(command -v ccache >/dev/null 2>&1 && echo 'enabled' || echo 'not installed')"
_info "Exe src"      "example/$EXECUTABLE_SRC"
echo ""
# ===== Conan =====
USE_CONAN=OFF
if command -v conan >/dev/null 2>&1 && [ -f conanfile.txt ]; then
    echo "检测到 Conan，安装依赖..."
    USE_CONAN=ON
    conan profile detect 2>/dev/null || true

    # cmake_layout 在项目根下生成 build/<BuildType>/generators/
    TOOLCHAIN_FILE="build/${BUILD_TYPE}/generators/conan_toolchain.cmake"

    # 工具链已有则跳过，除非 conanfile.txt 被更新
    if [ ! -f "$TOOLCHAIN_FILE" ] || [ conanfile.txt -nt "$TOOLCHAIN_FILE" ]; then
        conan install . -s build_type="$BUILD_TYPE" --output-folder=. --build=missing
    fi

    [ -f "$TOOLCHAIN_FILE" ] || { echo "错误: 找不到工具链 $TOOLCHAIN_FILE"; exit 1; }
fi

# ===== CMake =====
# 自动选择构建工具：ninja > make
BUILD_TOOL="make"
command -v ninja >/dev/null 2>&1 && BUILD_TOOL="ninja"

CMAKE_ARGS=(
    -B "$BUILD_DIR"
    -G "${BUILD_TOOL^}"              # Ninja 或 Unix Makefiles
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
    -DENABLE_ASAN="$ENABLE_ASAN"
    -DENABLE_TSAN="$ENABLE_TSAN"
    -DENABLE_UBSAN="$ENABLE_UBSAN"
    -DENABLE_PERF="$ENABLE_PERF"
    -DUSE_MARCH_NATIVE="$USE_MARCH_NATIVE"
    -DENABLE_LTO="$ENABLE_LTO"
    -DUSE_FOR_VALGRIND="$USE_FOR_VALGRIND"
)

# 仅当用户显式指定 --exe-src 时才传 cmake，否则由 cmake 缓存决定
[ "$_EXPLICIT_EXE_SRC" = "1" ] && CMAKE_ARGS+=(-DEXECUTABLE_SRC="$EXECUTABLE_SRC")

[ "$USE_CONAN" = "ON" ] && [ -f "${TOOLCHAIN_FILE:-}" ] && CMAKE_ARGS+=(-DCMAKE_TOOLCHAIN_FILE="$PWD/$TOOLCHAIN_FILE")

cmake "${CMAKE_ARGS[@]}"

# ===== 编译 =====
if [ "$BUILD_TOOL" = "ninja" ]; then
    ninja -C "$BUILD_DIR"
else
    make -C "$BUILD_DIR" -j"$(nproc)"
fi

# ===== 测试 =====
if [ "$RUN_TESTS" = "ON" ]; then
    echo ""
    echo "$HEAD Run Tests $HEAD"
    (cd "$BUILD_DIR" && ctest --output-on-failure)
fi
