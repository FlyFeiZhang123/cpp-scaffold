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
# 这里的默认值只在「绕过 my_build.bash、直接 cmake」时生效：脚本每次都会显式传
# -DENABLE_xxx，而命令行 -D 优先于 option()。两处写成一样的，免得两种入口给出
# 不同的构建结果（改默认值时别只改一边）。
option(ENABLE_ASAN   "AddressSanitizer"                    OFF)
option(ENABLE_TSAN   "ThreadSanitizer"                     OFF)
option(ENABLE_UBSAN  "UndefinedBehaviorSanitizer"          OFF)
option(USE_FOR_VALGRIND "Build with Valgrind-compatible debug info" OFF)
option(ENABLE_PERF   "Keep frame pointer for perf"         ON)
option(USE_MARCH_NATIVE "Enable -march=native (real HW)"   OFF)  # ← 开了产物绑本机 CPU，跨机/VM 会 SIGILL
option(ENABLE_LTO    "Link-time optimization"              OFF)
option(ENABLE_OPENMP "OpenMP parallelization"              OFF)
option(ENABLE_CCACHE "Use ccache if available"             ON)
set(INSTALL_GLOBAL   OFF)

# ===== 2. 编译选项 — 目录作用域：本项目此后创建的每个 target 都吃到 =====
# 为什么不用 target_compile_options：那东西只作用于显式点名的 target，而 target 散在
# 多个 CMakeLists 里（tests/ 下还有 unit_test 和 benchmark 两个），没人会记得给新
# target 补一行 —— 漏了不报错，只是默默不生效。踩过一次：老写法只覆盖了库和 exe，
# 测试和 bench 一个 flag 都没吃到，于是 ./my_build.bash asan test 跑的是没插桩的测试；
# 更阴的是库插桩、链接却不带 -fsanitize 时，报错是 `undefined reference to __asan_init`，
# 跟你的代码看不出半点关系。
#
# add_compile_options / add_link_options 是目录属性，会传给之后创建的 target、以及
# 之后 add_subdirectory 进去的子目录。所以这一段必须排在 add_library / add_executable
# / add_subdirectory(tests) **之前** —— 挪到文件下面去，库和 exe 反而漏了。
#
# 副作用：CPM 拉下来的 googletest / benchmark 也会吃到这些 flag。对 sanitizer 来说这
# 是必须的，不是污染 —— 插桩和没插桩的 TU 混链本身就不合法。
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")

  # ── 调试信息 ──
  if(USE_FOR_VALGRIND)
    add_compile_options(-gdwarf-4)
  else()
    add_compile_options(-gdwarf-5)
  endif()

  # ── 帧指针：perf 展开调用栈所需 ──
  if(ENABLE_PERF)
    add_compile_options(-fno-omit-frame-pointer)
  endif()

  # ── Sanitizers ──
  # 编译和链接必须成对：只加编译选项、链接不加，就是一堆 __asan_* 未定义引用。
  if(ENABLE_ASAN)
    add_compile_options(-fsanitize=address -O1)
    add_link_options(-fsanitize=address)
  elseif(ENABLE_TSAN)
    # TSan 需要大块连续虚拟内存，需关闭 ASLR
    # 用法: setarch $(uname -m) -R ./build/test_exe
    add_compile_options(-fsanitize=thread -O1)
    add_link_options(-fsanitize=thread)
  endif()

  if(ENABLE_UBSAN)
    # -fno-sanitize-recover=all 不能少：默认 UBSan 是「打印一行然后继续跑」，退出码仍为
    # 0，ctest 判不出来 —— 带 UB 的代码照样绿。加上它才是撞到就 abort、测试真的变红。
    add_compile_options(-fsanitize=undefined -fno-sanitize-recover=all)
    add_link_options(-fsanitize=undefined)
  endif()

  # ── LTO ──
  if(ENABLE_LTO)
    add_compile_options(-flto)
    add_link_options(-flto)
  endif()

  # ── OpenMP ──
  if(ENABLE_OPENMP)
    add_compile_options(-fopenmp)
    add_link_options(-fopenmp)
  endif()

  # ── -march=native ──
  if(USE_MARCH_NATIVE)
    include(CheckCXXCompilerFlag)
    check_cxx_compiler_flag(-march=native COMPILER_SUPPORTS_MARCH_NATIVE)
    if(COMPILER_SUPPORTS_MARCH_NATIVE)
      add_compile_options(-march=native)
      message(STATUS "启用 -march=native")
    endif()
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

# ===== 3. 依赖 — 去 cmake/Dependencies.cmake 里声明 =====
include(cmake/Dependencies.cmake)

file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS "src/*.cpp") #从这里触发增量管理，不需要重新编译了，大多数时候效率更高

# ===== 4. 创建库 =====
# PRIVATE：头文件路径只对当前目标（${LIB_NAME}）的内部源文件（.cpp）生效，不会传递给链接 ${LIB_NAME} 的其他目标（如 test_exe）。
# 如果你的公共头文件（include/test.h）中包含了 muduo 头文件，那么 test_exe 在编译时（因为它包含了 test.h）仍然会找不到 muduo 头文件，导致编译错误。
# PUBLIC：头文件路径不仅对当前目标的源文件生效，还会传递给所有链接此目标的下游目标。这样 test_exe 也能自动获得 muduo 的头文件搜索路径。
# INTERFACE：仅用于传递头文件路径给下游目标，当前目标自身的源文件不包含（适用于纯头文件库）。这里不适用。
add_library(${LIB_NAME} ${SOURCES})
target_include_directories(${LIB_NAME} PUBLIC include/)   # 库的头文件公开给链接者，这里如果想要让这个传递给test,需要link_libraries的时候用PUBLIC

# ===== 4.5 第三方库统一链接（依赖在 cmake/Dependencies.cmake 里声明，这里集中处理）=====
# 例：target_link_libraries(${LIB_NAME} PRIVATE nlohmann_json::nlohmann_json fmt::fmt)

# ===== 5. 创建可执行文件 =====
add_executable(${EXECUTABLE_NAME} example/${EXECUTABLE_SRC})
target_include_directories(${EXECUTABLE_NAME} PRIVATE include/)
target_link_libraries(${EXECUTABLE_NAME} PRIVATE ${LIB_NAME} )
# target_link_libraries(${EXECUTABLE_NAME} PRIVATE behaviortree_cpp::behaviortree_cpp)

# 软链接由 my_build.bash 在每次构建后自动更新：build/<可执行文件名> → 当前构建目录下的二进制

# （编译选项不在这里：见文件顶部的「2. 编译选项」。目录作用域只能影响其后创建的
#  target，所以那一段必须排在 add_library / add_executable / add_subdirectory 之前。
#  原来这里那套 apply_flags() 函数已经删掉。）

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

