# ============================================================================
# 项目依赖 — 三级降级链：find_package → third_party/ → FetchContent
# ============================================================================

include(FetchContent)
set(THIRD_PARTY_DIR         "${CMAKE_CURRENT_SOURCE_DIR}/third_party")   # 源码持久化目录
set(FETCHCONTENT_BINARY_DIR "${CMAKE_BINARY_DIR}/_deps")                # 构建产物留在 build

# ── 在此添加你的依赖 ──
# 模板：
# find_package(xxx QUIET)
# if(NOT xxx_FOUND)
#     if(EXISTS "${THIRD_PARTY_DIR}/xxx")
#         add_subdirectory(${THIRD_PARTY_DIR}/xxx xxx-build)
#     else()
#         FetchContent_Declare(
#             xxx
#             GIT_REPOSITORY https://github.com/...
#             GIT_TAG v1.2.3
#             SOURCE_DIR ${THIRD_PARTY_DIR}/xxx
#             BINARY_DIR ${FETCHCONTENT_BINARY_DIR}/xxx-build
#         )
#         set(FETCHCONTENT_UPDATES_DISCONNECTED TRUE)
#         FetchContent_MakeAvailable(xxx)
#     endif()
# endif()
