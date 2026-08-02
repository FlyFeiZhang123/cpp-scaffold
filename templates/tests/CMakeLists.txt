# ===== 单元测试 (doctest) =====
# 本地优先，离线可用；否则从 GitHub 拉取
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/doctest")
    set(DOCTEST_URL "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/doctest")
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
include(${doctest_SOURCE_DIR}/scripts/cmake/doctest.cmake)

file(GLOB TEST_SOURCES "unit/*.cpp")

add_executable(${PROJECT_NAME}_unit_test ${TEST_SOURCES})
target_link_libraries(${PROJECT_NAME}_unit_test PRIVATE ${LIB_NAME})
target_include_directories(${PROJECT_NAME}_unit_test PRIVATE
    ${PROJECT_SOURCE_DIR}/include
    ${doctest_SOURCE_DIR}
)

enable_testing()
doctest_discover_tests(${PROJECT_NAME}_unit_test)

# ===== 性能基准测试 (Google Benchmark) =====
option(BUILD_BENCHMARKS "Build benchmarks" ON)
if(BUILD_BENCHMARKS)
    # 本地优先，否则 GitHub
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/google-benchmark")
        set(BENCH_URL "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/google-benchmark")
    else()
        set(BENCH_URL "https://github.com/google/benchmark.git")
    endif()
    FetchContent_Declare(
        benchmark
        GIT_REPOSITORY ${BENCH_URL}
        GIT_TAG v1.9.4
    )
    set(BENCHMARK_ENABLE_TESTING OFF CACHE BOOL "" FORCE)
    set(BENCHMARK_ENABLE_LIBPFM ON CACHE BOOL "" FORCE)
    set(BENCHMARK_ENABLE_WERROR OFF CACHE BOOL "" FORCE)
    FetchContent_MakeAvailable(benchmark)

    file(GLOB BENCH_SOURCES "benchmark/*.cpp")

    add_executable(${PROJECT_NAME}_benchmark ${BENCH_SOURCES})
    target_link_libraries(${PROJECT_NAME}_benchmark PRIVATE ${LIB_NAME} benchmark::benchmark)
    target_include_directories(${PROJECT_NAME}_benchmark PRIVATE
        ${PROJECT_SOURCE_DIR}/include
    )

    # 注册到 CTest（CI 模式下限时快跑，手动跑不限时）
    # PMU 硬件计数器：CACHE-MISSES / CACHE-REFERENCES / CYCLES / BRANCH-MISSES
    # 需要依赖 libpfm4-dev，若未安装会输出警告（不影响 benchmark 运行）
    add_test(NAME ${PROJECT_NAME}_benchmark
        COMMAND ${PROJECT_NAME}_benchmark
            --benchmark_min_time=0.01
            --benchmark_perf_counters=CACHE-MISSES,CACHE-REFERENCES,CYCLES,BRANCH-MISSES
            --benchmark_counters_tabular=true
    )
endif()
