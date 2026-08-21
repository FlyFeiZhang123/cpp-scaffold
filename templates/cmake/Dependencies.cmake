# ============================================================================
# 项目依赖 — 在此声明所有第三方库
# ============================================================================

# ── CPM.cmake 初始化 ──
if(NOT DEFINED CPM_SOURCE_CACHE)
    set(CPM_SOURCE_CACHE "$ENV{HOME}/.cache/cpm" CACHE PATH "CPM.cmake 共享源码缓存（下载一次 → 永久离线）")
endif()
set(CPM_USE_LOCAL_PACKAGES ON CACHE BOOL "CPM 先 find_package（conan 装好的优先）")
include(${CMAKE_CURRENT_LIST_DIR}/CPM.cmake)

# ════════════════════════════════════════════════════════════════════════════
# 普通库依赖 — 声明区（只管"拉哪些包"），链接统一在根 CMakeLists.txt
# ════════════════════════════════════════════════════════════════════════════
#
# 三层原则：
#   conan 能装               → conanfile.txt 声明（conan install）
#   conan 没有，GitHub 有源码 → 下面用 CPMAddPackage 一行拉取  ← 加在这里
#   需要 patch / 私有         → third_party/ vendored，add_subdirectory
#
# 写法① GIT_TAG 显式写法（推荐，版本号带 v 也没关系，和 doctest/benchmark 一致）：
#   CPMAddPackage(
#       NAME nlohmann_json
#       GITHUB_REPOSITORY nlohmann/json
#       GIT_TAG v3.11.3
#   )
#
# 写法② 简写（CPM 官方推广，注意 @ 后面的版本号【别带 v】，否则会拼成 vvX.Y.Z 的错 tag）：
#   CPMAddPackage("gh:nlohmann/json@3.11.3")
#
# 写法③ 完整写法（要传 OPTIONS 时）：
#   CPMAddPackage(
#       NAME fmt
#       GITHUB_REPOSITORY fmtlib/fmt
#       GIT_TAG 11.1.3
#       OPTIONS "FMT_TEST OFF"        # fmt 自带的测试，CPM 拉下来时不需要
#   )
#
# 真实依赖声明从下面开始写：
#
#   CPMAddPackage(NAME nlohmann_json GITHUB_REPOSITORY nlohmann/json GIT_TAG v3.11.3)
#   CPMAddPackage(NAME fmt GITHUB_REPOSITORY fmtlib/fmt GIT_TAG 11.1.3 OPTIONS "FMT_TEST OFF")
#
# 声明之后，到根 CMakeLists.txt 的 target_link_libraries(${LIB_NAME} PRIVATE ...) 那一行，
# 把对应 target 加进去即可（一个库 → 一行里加一个名字），例如：
#   target_link_libraries(${LIB_NAME} PRIVATE nlohmann_json::nlohmann_json fmt::fmt)
#
# 离线：CPM_SOURCE_CACHE 缓存后，新项目/新构建不再联网。
#       conan 与 CPM 同时声明同一依赖时，CPM_USE_LOCAL_PACKAGES=ON 让 CPM 优先用 conan 的。

# ════════════════════════════════════════════════════════════════════════════
# 测试框架依赖 — 见 tests/CMakeLists.txt
# ════════════════════════════════════════════════════════════════════════════
# doctest（单元测试）与 Google Benchmark（性能基准）在 tests/CMakeLists.txt 里
# 用 CPMAddPackage 声明，只在构建测试时拉取，不污染主程序的链接。

