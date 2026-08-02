cmake_minimum_required(VERSION 3.20)

set(PROJECT_NAME __PROJECT_NAME__)
set(LIB_NAME ${PROJECT_NAME}_lib)
set(EXECUTABLE_NAME __EXECUTABLE_NAME__)
set(EXECUTABLE_SRC "main.cpp" CACHE STRING "Source file for the executable (relative to example/)")

project(${PROJECT_NAME} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ===== 1. 选项 =====
option(ENABLE_ASAN   "AddressSanitizer"                    ON)
option(ENABLE_TSAN   "ThreadSanitizer"                     OFF)
option(ENABLE_UBSAN  "UndefinedBehaviorSanitizer"          OFF)
option(USE_FOR_VALGRIND "Build with Valgrind-compatible debug info" OFF)
option(ENABLE_PERF   "Keep frame pointer for perf"         ON)
option(USE_MARCH_NATIVE "Enable -march=native (real HW)"   ON)   # ← WSL2 VM 上不要开
option(ENABLE_LTO    "Link-time optimization"              OFF)
option(ENABLE_CCACHE "Use ccache if available"             ON)
set(INSTALL_GLOBAL   OFF)

# WSL2 兼容：非 VM 环境可用 -march=native
if(USE_MARCH_NATIVE)
  include(CheckCXXCompilerFlag)
  check_cxx_compiler_flag(-march=native COMPILER_SUPPORTS_MARCH_NATIVE)
  if(COMPILER_SUPPORTS_MARCH_NATIVE)
    add_compile_options(-march=native)
    message(STATUS "启用 -march=native")
  endif()
endif()

if(ENABLE_ASAN AND ENABLE_TSAN)
  message(FATAL_ERROR "ASan and TSan cannot be enabled simultaneously!")
endif()

# ccache
if(ENABLE_CCACHE)
  find_program(CCACHE_PROGRAM ccache)
  if(CCACHE_PROGRAM)
    set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
    message(STATUS "ccache 已启用: ${CCACHE_PROGRAM}")
  endif()
endif()

# ===== 2. 依赖（三种获取方式） =====
#
# 方式一：find_package — 库已编译安装（系统 apt / Conan / 手动 install）
#   find_package(fmt REQUIRED)
#   target_link_libraries(${LIB_NAME} PRIVATE fmt::fmt)
#
#   如果库装在非标准路径（如自己编的放在 /root/xxx/install）：
#     list(APPEND CMAKE_PREFIX_PATH "/root/xxx/install")
#     find_package(behaviortree_cpp REQUIRED)
#
# 方式二：add_subdirectory — 源码在本地（git submodule / vendor）
#   add_subdirectory(third_party/muduo muduo_build)
#   target_link_libraries(${LIB_NAME} PRIVATE muduo_net muduo_base)
#   target_include_directories(${LIB_NAME} PUBLIC third_party/muduo/include)
#
# 方式三：FetchContent — 自动下载 + add_subdirectory，统一写在 cmake/Dependencies.cmake
include(cmake/Dependencies.cmake)

file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS "src/*.cpp") #从这里触发增量管理，不需要重新编译了，大多数时候效率更高

# ===== 3. 创建库 =====
# PRIVATE：头文件路径只对当前目标（${LIB_NAME}）的内部源文件（.cpp）生效，不会传递给链接 ${LIB_NAME} 的其他目标（如 test_exe）。
# 如果你的公共头文件（include/test.h）中包含了 muduo 头文件，那么 test_exe 在编译时（因为它包含了 test.h）仍然会找不到 muduo 头文件，导致编译错误。
# PUBLIC：头文件路径不仅对当前目标的源文件生效，还会传递给所有链接此目标的下游目标。这样 test_exe 也能自动获得 muduo 的头文件搜索路径。
# INTERFACE：仅用于传递头文件路径给下游目标，当前目标自身的源文件不包含（适用于纯头文件库）。这里不适用。
add_library(${LIB_NAME} ${SOURCES})
target_include_directories(${LIB_NAME} PUBLIC include/)   # 库的头文件公开给链接者，这里如果想要让这个传递给test,需要link_libraries的时候用PUBLIC

# ===== 4. 创建可执行文件 =====
add_executable(${EXECUTABLE_NAME} example/${EXECUTABLE_SRC})
target_include_directories(${EXECUTABLE_NAME} PRIVATE include/)
target_link_libraries(${EXECUTABLE_NAME} PRIVATE ${LIB_NAME} )
# target_link_libraries(${EXECUTABLE_NAME} PRIVATE behaviortree_cpp::behaviortree_cpp)

# 软链接由 my_build.bash 在每次构建后自动更新：build/<可执行文件名> → 当前构建目录下的二进制

# ===== 5. 编译选项 — 统一应用到库和可执行文件 =====
# 用函数消除重复
function(apply_flags flag)
  target_compile_options(${LIB_NAME} PRIVATE ${flag})
  target_compile_options(${EXECUTABLE_NAME} PRIVATE ${flag})
endfunction()

function(apply_link_flags flag)
  target_link_options(${LIB_NAME} PRIVATE ${flag})
  target_link_options(${EXECUTABLE_NAME} PRIVATE ${flag})
endfunction()

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")

  # ── 调试信息 ──
  if(USE_FOR_VALGRIND)
    apply_flags(-gdwarf-4)
  else()
    apply_flags(-gdwarf-5)
  endif()

  # ── 帧指针：perf 展开调用栈所需 ──
  if(ENABLE_PERF)
    apply_flags(-fno-omit-frame-pointer)
  endif()

  # ── Sanitizers ──
  if(ENABLE_ASAN)
    apply_flags(-fsanitize=address -O1)
    apply_link_flags(-fsanitize=address)
  elseif(ENABLE_TSAN)
    # TSan 需要大块连续虚拟内存，需关闭 ASLR
    # 用法: setarch $(uname -m) -R ./build/test_exe
    apply_flags(-fsanitize=thread -O1)
    apply_link_flags(-fsanitize=thread)
  endif()

  if(ENABLE_UBSAN)
    apply_flags(-fsanitize=undefined -fno-sanitize-recover=all)
    apply_link_flags(-fsanitize=undefined)
  endif()

  # ── LTO ──
  if(ENABLE_LTO)
    apply_flags(-flto)
    apply_link_flags(-flto)
  endif()

endif()

# ===== 6. 安装 =====
if(INSTALL_GLOBAL)
  install(TARGETS ${LIB_NAME} LIBRARY DESTINATION /usr/lib)
  install(DIRECTORY include/ DESTINATION /usr/include/${LIB_NAME}
          FILES_MATCHING PATTERN "*.h")
  message(STATUS "安装已启用：库 → /usr/lib，头文件 → /usr/include/${LIB_NAME}")
endif()

# ===== 7. 测试 =====
option(BUILD_TESTS "Build tests" ON)
if(BUILD_TESTS)
  enable_testing()
  add_subdirectory(tests)
endif()

