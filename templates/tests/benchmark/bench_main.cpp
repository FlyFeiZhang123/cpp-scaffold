#include <benchmark/benchmark.h>

#include "calculator.h"

// ── Calculator benchmarks ──
static void bm_calculator_add(benchmark::State& state) {
    Calculator calc;
    for (auto _ : state) {
        benchmark::DoNotOptimize(calc.add(2, 3));
    }
}
BENCHMARK(bm_calculator_add);

static void bm_calculator_mul(benchmark::State& state) {
    Calculator calc;
    for (auto _ : state) {
        benchmark::DoNotOptimize(calc.mul(7, 8));
    }
}
BENCHMARK(bm_calculator_mul);

static void bm_calculator_div(benchmark::State& state) {
    Calculator calc;
    for (auto _ : state) {
        benchmark::DoNotOptimize(calc.div(100, 4));
    }
}
BENCHMARK(bm_calculator_div);

BENCHMARK_MAIN();
