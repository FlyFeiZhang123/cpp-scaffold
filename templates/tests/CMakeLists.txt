include(FetchContent)
FetchContent_Declare(
    doctest
    GIT_REPOSITORY https://github.com/doctest/doctest.git
    GIT_TAG v2.4.11
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
