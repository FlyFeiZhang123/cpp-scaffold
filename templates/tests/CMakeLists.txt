# 本地优先，离线可用；否则从 GitHub 拉取
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../doctest-offline")
    set(DOCTEST_URL "${CMAKE_CURRENT_SOURCE_DIR}/../doctest-offline")
    set(DOCTEST_TAG "")
else()
    set(DOCTEST_URL "https://github.com/doctest/doctest.git")
    set(DOCTEST_TAG v2.4.11)
endif()

include(FetchContent)
FetchContent_Declare(
    doctest
    GIT_REPOSITORY ${DOCTEST_URL}
    GIT_TAG ${DOCTEST_TAG}
)
FetchContent_MakeAvailable(doctest)

# 手动加载 doctest 的 CMake 辅助脚本 (提供 doctest_discover_tests)
include(${doctest_SOURCE_DIR}/scripts/cmake/doctest.cmake)

file(GLOB TEST_SOURCES "*.cpp")

add_executable(${PROJECT_NAME}_unit_test ${TEST_SOURCES})
target_link_libraries(${PROJECT_NAME}_unit_test PRIVATE ${LIB_NAME})          # 不再链接 doctest
target_include_directories(${PROJECT_NAME}_unit_test PRIVATE
    ${PROJECT_SOURCE_DIR}/include
    ${doctest_SOURCE_DIR}   # 让 #include <doctest/doctest.h> 能找到
)

enable_testing()                        # 既然顶层已经开启，这一行保留也无害
doctest_discover_tests(${PROJECT_NAME}_unit_test)
