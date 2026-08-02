#pragma once
// CPU 亲和性绑定 — benchmark 绑核用
//
// 为什么需要：
//   不绑核时，CFS 调度器会在物理核之间漂移线程，每次漂移 L1/L2 cache
//   全部作废（冷 cache 惩罚 ~100ns/次），导致 benchmark 数据方差巨大。
//
// 正确用法：
//   - 绑到 0, 2, 4, 6... 这种隔开的物理核（避开超线程对）
//   - Linux 下物理核成对：0&1 共享、2&3 共享...，绑同一对的两个超线程
//     会抢执行单元，反而更慢
//   - 在 Google Benchmark fixture 的 SetUp 中调用 pin_to_core()
//   - 或者运行时用 taskset -c <core> （bench_use.bash --bind <core> 已支持）

#include <pthread.h>

inline void pin_to_core(int core_id) {
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(core_id, &cpuset);
    pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset);
}
