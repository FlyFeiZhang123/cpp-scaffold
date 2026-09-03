# ===== 测试依赖（CPM：下载一次 → CPM_SOURCE_CACHE 缓存，之后离线可用）=====
# CPM 已由 cmake/Dependencies.cmake 初始化，这里直接用 CPMAddPackage

# ===== 单元测试 (GoogleTest) =====
CPMAddPackage(
    NAME googletest
    GITHUB_REPOSITORY google/googletest
    GIT_TAG v1.17.0
    FORCE   # 框架依赖固定走 CPM，与 benchmark 一致，版本钉死
)

file(GLOB TEST_SOURCES "unit/*.cpp")

add_executable(${PROJECT_NAME}_unit_test ${TEST_SOURCES})
target_link_libraries(${PROJECT_NAME}_unit_test PRIVATE ${LIB_NAME} gtest_main)
target_include_directories(${PROJECT_NAME}_unit_test PRIVATE
    ${PROJECT_SOURCE_DIR}/include
)

enable_testing()
include(GoogleTest)
gtest_discover_tests(${PROJECT_NAME}_unit_test)

# ===== 性能基准测试 (Google Benchmark) =====
option(BUILD_BENCHMARKS "Build benchmarks" ON)
if(BUILD_BENCHMARKS)
    CPMAddPackage(
        NAME benchmark
        GITHUB_REPOSITORY google/benchmark
        GIT_TAG v1.9.5
        OPTIONS
            "BENCHMARK_ENABLE_TESTING OFF"
            "BENCHMARK_ENABLE_LIBPFM ON"
            "BENCHMARK_ENABLE_WERROR OFF"
        FORCE
    )

    file(GLOB BENCH_SOURCES "benchmark/*.cpp")

    add_executable(${PROJECT_NAME}_benchmark ${BENCH_SOURCES})
    target_link_libraries(${PROJECT_NAME}_benchmark PRIVATE ${LIB_NAME} benchmark::benchmark)
    target_include_directories(${PROJECT_NAME}_benchmark PRIVATE
        ${PROJECT_SOURCE_DIR}/include
    )

    add_test(NAME ${PROJECT_NAME}_benchmark
        COMMAND ${PROJECT_NAME}_benchmark
            --benchmark_min_time=0.01
    )
endif()
