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
#   需要 patch / 私有 / 本地改装 → third_party/ vendored，或下方"写法④⑤⑥"的 CPM 本地机制
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
# ════════════════════════════════════════════════════════════════════════════
# 本地改装：不用 CPM 拉远程，改用自己改过的版本（三个机制，按场景选一种）
# ════════════════════════════════════════════════════════════════════════════
#   fork 整个库 / 改动很多  → third_party/ vendored（见写法④，详见 third_party/README.md）
#   平时官方、偶尔切本地调试 → CPM_<NAME>_SOURCE 变量手动覆盖（见写法⑤）
#   只改官方库几个文件       → PATCHES 打补丁（见写法⑥）
#
# 写法④ vendored：把改好的源码整个放进 third_party/，两种接法：
#   add_subdirectory(third_party/foo)                        # 直连（target 名要和库产出的一致）
#   CPMAddPackage(NAME foo SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/third_party/foo)
#                                                           # 走 CPM 流程，foo_SOURCE_DIR 等变量照常导出
#
# 写法⑤ 手动覆盖（在 CPMAddPackage 之前 set，注释即恢复官方）：
#   # set(CPM_fmt_SOURCE "/home/me/forks/fmt")
#   CPMAddPackage(NAME fmt GITHUB_REPOSITORY fmtlib/fmt GIT_TAG 11.1.3)
#
# 写法⑥ 打补丁（补丁文件放 patches/，随项目进 git）：
#   CPMAddPackage(NAME foo GITHUB_REPOSITORY foo/foo GIT_TAG v1.0
#                 PATCHES ${CMAKE_CURRENT_SOURCE_DIR}/patches/foo.patch)
#
# 覆盖优先级：CPM_<NAME>_SOURCE 本地目录 > find_package(conan) > 远程拉取
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

