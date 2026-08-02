# ===== 依赖获取策略 =====
# vendor (third_party/) 直接 add_subdirectory；否则 FetchContent (GitHub)
include(FetchContent)

# ===== 单元测试 (doctest) =====
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/doctest")
    set(doctest_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/doctest")
    add_subdirectory(${doctest_SOURCE_DIR} "${CMAKE_BINARY_DIR}/_deps/doctest")
else()
    FetchContent_Declare(
        doctest
        GIT_REPOSITORY https://github.com/doctest/doctest.git
        GIT_TAG v2.4.11
    )
    FetchContent_MakeAvailable(doctest)
endif()
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
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/google-benchmark")
        set(benchmark_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/google-benchmark")
        set(BENCHMARK_ENABLE_TESTING OFF CACHE BOOL "" FORCE)
        set(BENCHMARK_ENABLE_LIBPFM ON CACHE BOOL "" FORCE)
        set(BENCHMARK_ENABLE_WERROR OFF CACHE BOOL "" FORCE)
        add_subdirectory(${benchmark_SOURCE_DIR} "${CMAKE_BINARY_DIR}/_deps/benchmark")
    else()
        FetchContent_Declare(
            benchmark
            GIT_REPOSITORY https://github.com/google/benchmark.git
            GIT_TAG v1.9.4
        )
        set(BENCHMARK_ENABLE_TESTING OFF CACHE BOOL "" FORCE)
        set(BENCHMARK_ENABLE_LIBPFM ON CACHE BOOL "" FORCE)
        set(BENCHMARK_ENABLE_WERROR OFF CACHE BOOL "" FORCE)
        FetchContent_MakeAvailable(benchmark)
    endif()

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
