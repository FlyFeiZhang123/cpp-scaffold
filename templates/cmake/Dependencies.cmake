# ============================================================================
# 项目依赖 — 在此声明所有第三方库
# ============================================================================

include(FetchContent)
set(THIRD_PARTY_DIR         "${CMAKE_CURRENT_SOURCE_DIR}/third_party")   # 源码持久化目录
set(FETCHCONTENT_BINARY_DIR "${CMAKE_BINARY_DIR}/_deps")                # 构建产物留在 build

# ── 在此添加你的依赖 ──

# 模式一：三级降级链（QUIET + fallback）— 适用于大多数第三方库
#   find_package(xxx QUIET)                                    # ① 系统已安装就用系统的
#   if(NOT xxx_FOUND)
#       if(EXISTS "${THIRD_PARTY_DIR}/xxx")                    # ② 本地有源码直接 add_subdirectory
#           add_subdirectory(${THIRD_PARTY_DIR}/xxx xxx-build)
#       else()
#           FetchContent_Declare(                              # ③ 都没有就自动下载
#               xxx
#               GIT_REPOSITORY https://github.com/...
#               GIT_TAG v1.2.3
#               SOURCE_DIR ${THIRD_PARTY_DIR}/xxx
#               BINARY_DIR ${FETCHCONTENT_BINARY_DIR}/xxx-build
#           )
#           set(FETCHCONTENT_UPDATES_DISCONNECTED TRUE)
#           FetchContent_MakeAvailable(xxx)
#       endif()
#   endif()

# 模式二：直接 REQUIRED — 编译器自带或系统库或者conan包含的，不需要降级
#   find_package(OpenMP  REQUIRED)
#   find_package(Threads REQUIRED)

# 如果库装在非标准路径（如自己编在 /opt/xxx）：
#(1)自定义目录
#   list(APPEND CMAKE_PREFIX_PATH "/opt/xxx")
#   find_package(xxx REQUIRED)          #modern cmake模板到这里就够了，但是老项目没有target需要下面两步
#(2)和目录一块的third_party 下的通过git submodule下载的源码
# 如果是third_party/ add_subdirectory — 源码在本地（git submodule / vendor）
#   add_subdirectory(third_party/muduo muduo_build)
# 注：如果不是现代cmake,没有target的，需要手动指定头文件和库文件，如下
#   target_link_libraries(${LIB_NAME} PRIVATE muduo_net muduo_base)
#   target_include_directories(${LIB_NAME} PUBLIC third_party/muduo/include)

#  以下是链接目标，而不声明target，这个步骤一般在根目录的CMakeLists.txt里做
#   target_link_libraries(${LIB_NAME} PRIVATE OpenMP::OpenMP_CXX Threads::Threads)