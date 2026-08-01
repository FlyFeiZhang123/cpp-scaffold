#include <benchmark/benchmark.h>

#include "calculator.h"

// ============================================================================
// PMU 硬件计数器 — 运行时追加参数即可采集 cache miss 等硬件事件
// ============================================================================
// 前提：
//   1. Google Benchmark 编译时开启 BENCHMARK_ENABLE_LIBPFM（依赖 libpfm4-dev）
//      sudo apt install libpfm4-dev
//   2. 内核允许用户态读取 PMU 计数器（检查 /proc/sys/kernel/perf_event_paranoid）
//      sudo sysctl kernel.perf_event_paranoid=2
//     永久: echo "kernel.perf_event_paranoid=2" | sudo tee -a /etc/sysctl.conf
//
// 用法：
//   # 只跑 benchmark（基础时间）
//   ./build/test_benchmark
//
//   # 带上硬件计数器（cache miss / cycles / branch misses）
//   ./build/test_benchmark \
//       --benchmark_perf_counters=CACHE-MISSES,CACHE-REFERENCES,CYCLES,BRANCH-MISSES \
//       --benchmark_counters_tabular=true
//
//   # 绑核跑（避免线程漂移导致数据抖动）
//   taskset -c 0 ./build/test_benchmark \
//       --benchmark_perf_counters=CACHE-MISSES,CACHE-REFERENCES,CYCLES,BRANCH-MISSES
//
//   # 输出 JSON 对接 CI
//   ./build/test_benchmark \
//       --benchmark_perf_counters=CACHE-MISSES,CACHE-REFERENCES \
//       --benchmark_format=json \
//       --benchmark_out=bench_results.json
//
// 输出示例：
//   Benchmark             Time      CPU       Iterations  CACHE-MISSES  CACHE-REFERENCES  CYCLES
//   bm_calculator_add     0.611 ns  0.611 ns  1000000000  1000p         52n               81.6163u
//
//   后缀: p = pico(10⁻¹²), n = nano(10⁻⁹), u = micro(10⁻⁶) — 每次迭代的事件平均数
//
// 目标：Cache Miss 率 < 20%。若超，优先排查：
//   - vector<Object> → 是否连续存储（避免指针追逐）
//   - AoS → SoA：热字段分离到独立连续数组
//   - 避免 std::list / std::map 等跳跃式结构
// ============================================================================

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
