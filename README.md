# cpp-scaffold — C++ 项目脚手架

一套现代 C++ 开发环境模板，一键装环境、一键建项目、一键编译调试。

---

## 功能一览

| 功能     | 工具                     | 说明                                    |
| -------- | ------------------------ | --------------------------------------- |
| 构建系统 | CMake 3.20+ + Ninja/Make | 支持 Debug / Release / Sanitizer 多配置 |
| 包管理   | Conan 2.x                | 可选，通过 `conanfile.txt` 开启         |
| 依赖管理 | CPM.cmake + Conan          | conan 覆盖的走 conan；其余 CPM 一行拉取，CPM_SOURCE_CACHE 离线缓存 |
| 代码补全 | clangd                   | VS Code / Zed 配置已内置                |
| Tab 补全 | bash completion          | `my_build.bash`/`bench_use.bash`/`perf_use.bash`/`task_tracker.bash` 原生补全 |
| 代码格式化 | clang-format + clang-tidy | 模板自带                               |
| 单元测试 | GoogleTest               | CPM 自动获取（钉 v1.17.0），CPM_SOURCE_CACHE 离线缓存 |
| 性能基准 | Google Benchmark         | `./bench_use.bash` 一键跑分，PMU 硬件计数器 |
| 任务追踪 | bash 脚本                | `./task_tracker.bash` 记录待办，附件/标签/统计，零依赖 |
| 项目更新 | bash 脚本                | 项目目录里敲 `updproj` 更新到脚手架当前版本（A 覆盖 / B 不碰 / C 只报告），默认只看不改 |
| 内存检测 | ASan / TSan / UBSan      | 编译参数一键切换                        |
| 内存泄漏 | Valgrind                 | 兼容 dwarf-4 调试信息                   |
| 性能分析 | perf + FlameGraph        | 三种采样模式，一键生成火焰图            |
| 文档生成 | Doxygen                  | 配置模板已含                            |

---

## 快速开始

### 1. 安装环境（只需一次）

```bash
# GitHub（主仓库）
git clone git@github.com:FlyFeiZhang123/cpp-scaffold.git ~/cpp-scaffold

# Gitee（国内镜像，速度快）
git clone git@gitee.com:flyzhang123/cpp-scaffold.git ~/cpp-scaffold

cd ~/cpp-scaffold

# 国内网络先换源（阿里云 + 清华双源，自动适配 x86_64/ARM64,如果需要的话）
sudo ./scripts/setup_mirror.bash

# 一键安装：gcc、cmake、ninja、clangd、conan、perf、FlameGraph 等
./setup_all.bash
```

> 支持 Ubuntu 22.04 / 24.04 / 26.04，x86_64 和 ARM64 架构。
>
> 注：Conan 用 uv 安装（装到 `~/.local/bin`）。若本机没有 uv，`conan_install.bash`
> 会自动执行官方脚本 `curl -LsSf https://astral.sh/uv/install.sh | sh`（需联网）。
> 介意自动执行远程脚本的话，可先手动装好 uv 再跑 setup_all。

### 2. 配置快捷命令

`setup_all.bash` 已自动将以下内容写入 `~/.bashrc`：

```bash
export BASE_SETTINGS_DIR="$HOME/cpp-scaffold"

# 补全 + 环境设置（settings_use.bash / my_build.bash / bench_use.bash / perf_use.bash / task_tracker.bash）
for f in "$BASE_SETTINGS_DIR"/templates/completions/*.bash; do
    [ -f "$f" ] && source "$f"
done
```

新终端或 `source ~/.bashrc` 后即可使用 `newproj` 命令和 tab 补全。

### 3. 创建新项目

```bash
# 基本项目 + Zed 配置（默认）
newproj my_project my_app

# Conan + VS Code 配置
newproj my_project my_app y v
```

会在当前目录生成：

```
my_project/
├── CMakeLists.txt
├── conanfile.txt              # 如果指定了 y
├── .gitignore
├── .clang-format
├── .clang-tidy
├── README.md
├── include/
├── src/
├── tests/
│   ├── CMakeLists.txt
│   ├── unit/
│   │   └── test_main.cpp      # GoogleTest 单元测试
│   └── benchmark/
│       ├── bench_main.cpp     # Google Benchmark 性能基准
│       └── pin_thread.h       # 绑核工具
├── cmake/
│   ├── CPM.cmake              # CPM 依赖管理（vendored）
│   └── Dependencies.cmake     # 依赖声明（CPM / conan / vendored）
├── tools/
│   └── benchmark_tools/       # bench_use --compare 用的 compare.py + gbench
├── example/
│   └── main.cpp
├── out/                      # 输出文件（perf / benchmark / heaptrack / logs）
│   ├── perf/
│   ├── bench/
│   ├── heaptrack/
│   └── logs/
├── .vscode/                  # VS Code 配置（选 v 时）
│   ├── launch.json           #   调试配置（普通 + sudo 两种）
│   ├── settings.json         #   clangd + CMake 配置
│   ├── tasks.json            #   F5 自动编译
│   └── sudo_gdb.sh           #   root 权限调试
├── .zed/                     # Zed 配置（选 z 时）
│   └── debug.json
├── my_build.bash             # 构建脚本
├── perf_use.bash             # 性能分析脚本
├── bench_use.bash            # Benchmark 脚本
├── task_tracker.bash         # 任务追踪脚本（数据在 docs/tasks/）
├── docs/                     # Doxygen 输出目录 + 任务数据（docs/tasks/）
└── Doxyfile                  # 文档配置
```

> 库名自动跟随项目名，例如 `my_project_lib`。
>
> **首次进入项目后，先编译一次**：生成二进制到 `build/` 目录，调试和 clangd 补全才能工作：
> ```bash
> ./my_build.bash
> ```

### 4. 编译项目

```bash
cd my_project

# 默认 Debug + ASan + 帧指针
./my_build.bash

# Release + 关闭 sanitizer
./my_build.bash release no-asan

# ThreadSanitizer
./my_build.bash tsan

# 编译并运行测试（含 unit test + benchmark）
./my_build.bash test

# 跳过 benchmark（加速 CI / 低配机器）
cmake -B build -DBUILD_BENCHMARKS=OFF .
./my_build.bash

# WSL2 关闭 -march=native
./my_build.bash no-march

# 链接时优化
./my_build.bash release lto

# OpenMP 并行（建议配合 release + -O3 使用）
./my_build.bash release no-asan openmp

# 指定入口文件
./my_build.bash --exe-src=main.cpp
```

### 5. 运行与调试

```bash
# 运行（build/app 为固定软链接，指向当前构建变体）
./build/app

# Valgrind 检测内存泄漏
valgrind --leak-check=full ./build/app

# ── 内存诊断 ──
# 看一眼进程内存全景（零开销，生产环境可用）
pmap -x $(pgrep -f build/app)

# 找占用最大的内存段
pmap -x $(pgrep -f build/app) | sort -k3 -n | tail -20

# 实时盯着，看内存涨不涨
watch -n 2 'pmap -x $(pgrep -f build/app) | tail -20'

```

| pmap 输出 | 判断 | 下一步 |
|-----------|------|--------|
| `[heap]` RSS 持续涨 | 堆泄漏（new/delete 问题） | heaptrack |
| `[anon]` 段又大又多 | mmap 或线程栈泄漏（每个 8MB） | 数段数 ≈ 线程数 |
| `.so` 的 RSS 异常大 | 动态库内部静态分配过大 | 读库源码 |
| `[stack]` 出现多个 | 线程创建了没回收 | 查线程管理逻辑 |

```bash
mkdir -p out/heaptrack
heaptrack -o out/heaptrack/app ./build/app

# 图形化分析（本地桌面，需安装: sudo apt install heaptrack heaptrack-gui）
heaptrack_gui $(ls -t out/heaptrack/app.*.gz | head -1)

# 纯文本报告（SSH / 无桌面环境）
heaptrack_print $(ls -t out/heaptrack/app.*.gz | head -1) | less

# ── Benchmark ──
# 表格输出 + PMU 计数器（cache miss / cycles / branch miss）
./bench_use.bash

# 绑核 + 过滤
./bench_use.bash --bind 0 --filter add

# 导出 JSON 并对比（自动存入 out/bench/）
./bench_use.bash --json --out v1.json
./bench_use.bash --json --out v2.json
./bench_use.bash --compare v1.json v2.json

# ── 性能采样 ──
# 默认采样 build/app，wrap 模式（程序结束自动停）
./perf_use.bash

# 指定程序 + 采样 30 秒（适合长期运行的程序）
./perf_use.bash ./build/app -t 30

# 手动按 Enter 停止（适合交互调试）
./perf_use.bash -m

# 浏览器查看火焰图
./perf_use.bash --serve
```

> **调试**：VS Code 中按 `F5` 即可，`launch.json` 已配置 `preLaunchTask` 自动编译。`build/app` 软链接由 `my_build.bash` 每次构建后自动更新，指向当前构建变体，调试始终正确。
>
> **Tab 补全**：所有脚本都支持 bash 原生 tab 补全（零依赖）。`--exe-src` 自动补 `=` 并补全 `example/*.cpp`，`--out` 自动补全 `out/bench/*.json`。`task_tracker.bash` 则会补当前项目的任务 ID 和已有标签名。`source ~/.bashrc` 后生效。
>
> **PMU 计数器**：`bench_use.bash` 默认读取 CPU 硬件计数器。若 `kernel.perf_event_paranoid > 2`（Ubuntu 24.04+ 默认），计数器列将显示 0。运行 `sudo sysctl kernel.perf_event_paranoid=2` 修复。
>
> **首次调试注意**：第一次启动调试时，VS Code 会下载 C++ 调试符号（debug symbols），国内网络可能需要梯子，首次准备时间会较长（几分钟到十几分钟不等），后续调试不会重复下载。

---

### 6. 任务追踪

`task_tracker.bash` 是个零依赖的单文件待办清单，数据就存在项目里（`docs/tasks/<id>/TASK.md`），跟着 git 走。参考 [tsoding/tatr](https://github.com/tsoding/tatr) 的设计。

```bash
# ── 记一件事 ──
./task_tracker.bash -m "重构渲染层"
./task_tracker.bash -m "修这个 bug" --tag bug,urgent

# 给已有任务补一句说明（ID 可以只写唯一的一段）
./task_tracker.bash -m 143129 "查到是缓存没失效"

# ── 看 ──
./task_tracker.bash -l                    # 没做完的
./task_tracker.bash -a                    # 全部
./task_tracker.bash -a --tag scope        # 按标签筛（多个标签是「与」）
./task_tracker.bash -t                    # 统计标签数量
./task_tracker.bash -t -u                 # 只统计没做完的

# ── 改 ──
./task_tracker.bash close 143129          # 改状态
./task_tracker.bash open  143129
./task_tracker.bash tag   143129 scope    # 加标签
./task_tracker.bash untag 143129 scope

# ── 附件 ──
./task_tracker.bash add 143129 截图.png          # 拷进任务目录（推荐）
./task_tracker.bash add 143129 --link src/main.cpp   # 只记路径，不拷贝
```

改标签用 `tag`/`untag`，改进度用 `open`/`close`，两根轴互不干涉——`close` 只改状态，标签原样留着。

> **`add` 的第一个参数必须是任务 ID**，选项写在它后面（`add 143129 --link x.png`，不能写 `add --link 143129 x.png`）。选项都是「粘性」的，对它后面的路径生效：`add <id> a.png --link b.png` 是 a 拷贝、b 只记路径。

> **`--link` 的坑**：只记路径，原文件一挪链接就断。而且预览器（VS Code 的 markdown 预览、GitHub）只放行工作区/仓库内的资源，**指向项目外的文件多半只显示破图标**——这种情况请去掉 `--link` 用默认的拷贝模式。
>
> LINK 记的是**从 TASK.md 算起的相对路径**，所以整棵 `docs/tasks/` 一挪位置（改名、移到别处），所有 LINK 全部失效，得手工改。

`-h` 有完整用法，`docs/tasks/tags` 可以给标签写说明（`-t` 统计时会缀在后面）。

---

### 7. 更新已有项目

脚手架自己演进了（换了测试框架、改了编译脚本），已有项目想跟上：

```bash
cd 你的项目
updproj          # 先看，一个字节都不改
updproj --apply  # 确认了再动盘
```

`updproj` 是 `scripts/update.bash` 的别名（跟 `newproj` 一样，由 `~/.bashrc` 里那段 source 循环带进来），在哪个目录敲就更新哪个项目，也可以 `updproj /path/to/项目`。没配别名就直接 `bash ~/cpp-scaffold/scripts/update.bash`。改动过 `settings_use.bash` 后要 `source ~/.bashrc` 或开个新终端才生效。

哪些文件归谁管写在仓库根的 `scaffold_files.list` 里（`install.bash` 和 `update.bash` 共用同一份清单，不会各写各的），按文件分三类：

| 类    | 是什么                                                                    | update 怎么做           |
| ----- | ------------------------------------------------------------------------- | ----------------------- |
| **A** | 脚手架自己的东西：几个 `.bash` 脚本、`cmake/CPM.cmake`、clang 配置、编辑器配置、`tools/` | **强制覆盖**，缺的补上  |
| **B** | 你的地盘：`src/`、`include/`、`example/`                                   | 一个字都不碰            |
| **C** | 两边都可能改：`CMakeLists.txt`、`README.md`、`.gitignore`、`tests/`        | **只看不写**（除下面一个） |

> ⚠ **A 类是强制覆盖，你对这些文件的本地改动会丢。** 它们本来就不该在项目里改 —— 要改就改脚手架仓库本身，下次 update 自然带过来。（`tools/` 是合并式覆盖：同名文件盖掉，你自己往里加的文件保留。）

C 类里只有 `CMakeLists.txt` 会被检查：脚本先把模板里的占位符换成你项目的真名，再跟你的比，**只报同不同**。因为你的项目名和自定义目标都在里面，脚本没资格替你决定。有差异时会打一份 diff，并给出重来一遍的命令：

```bash
rm CMakeLists.txt && newproj 你的项目名 你的可执行名
```

`install.bash` 只补不覆盖，所以删掉这一个文件就只重生成它。其余 C 类文件（README、`.gitignore`、`tests/` 等）脚本看都不看。

---

## 构建选项速查

| 参数                | 效果                                   |
| ------------------- | -------------------------------------- |
| `asan` / `no-asan`  | 开启/关闭 AddressSanitizer（默认开）   |
| `tsan`              | 开启 ThreadSanitizer（与 asan 互斥）   |
| `ubsan`             | 开启 UndefinedBehaviorSanitizer        |
| `perf` / `no-perf`  | 帧指针开关（默认开，火焰图需要）       |
| `march` / `no-march`| -march=native 开关（默认开）           |
| `lto`               | 启用链接时优化                         |
| `openmp` / `no-openmp` | OpenMP 并行（默认关，建议配合 release） |
| `valgrind`          | 生成 dwarf-4 调试信息（兼容 Valgrind） |
| `release` / `debug` | 构建类型，默认 Debug                   |
| `--exe-src=<file>`  | 指定 `example/` 下的入口源文件         |
| `test`              | 编译后运行 ctest（含 unit test + benchmark）|
| `-j<N>`             | 并发编译线程数（默认 `nproc`）            |

---

## 项目结构（模板仓库）

```
cpp-scaffold/
├── scripts/                 # 安装脚本
│   ├── setup_mirror.bash    #   apt 换源（阿里云主 + 清华副）
│   ├── basic_install.bash   #   基础开发工具（gcc/cmake/gdb/clangd/valgrind）
│   ├── extra_install.bash   #   额外工具（heaptrack/clang-tidy/iwyu）
│   ├── conan_install.bash   #   Conan 2.x
│   ├── perf_install.bash    #   perf + FlameGraph
│   ├── scaffold_lib.bash    #   install/update 共用：读清单、取项目名
│   ├── scaffold_test.bash   #   脚手架自测（CI 跑这个）
│   └── update.bash          #   更新已有项目（默认 dry-run）
├── scaffold_files.list      # ★ 文件清单：哪些文件、归 A/B/C 哪类，唯一真源
├── templates/               # 项目模板（会被复制到新项目）
│   ├── CMakeLists.txt
│   ├── .clang-format        #   复制到新项目
│   ├── .clang-tidy          #   复制到新项目
│   ├── conanfile.txt
│   ├── my_build.bash        #   构建脚本
│   ├── perf_use.bash        #   性能分析
│   ├── bench_use.bash       #   Benchmark 脚本
│   ├── task_tracker.bash    #   任务追踪（数据在项目的 docs/tasks/）
│   ├── cmake/
│   │   ├── CPM.cmake        #   CPM 依赖管理（vendored，钉版本）
│   │   └── Dependencies.cmake #   依赖声明（CPM / conan / vendored）
│   ├── Doxyfile
│   ├── example/
│   ├── tools/
│   │   └── benchmark_tools/  #   bench_use --compare 的 compare.py（vendored）
│   ├── tests/
│   │   ├── CMakeLists.txt
│   │   ├── unit/test_main.cpp     #   GoogleTest 单元测试
│   │   └── benchmark/
│   │       ├── bench_main.cpp       #   Google Benchmark
│   │       └── pin_thread.h         #   绑核工具
│   ├── include/calculator.h
│   ├── src/calculator.cpp
│   └── completions/         #   bash 补全（全局 source，不复制到项目）
├── .vscode/                 # VS Code 配置模板
│   ├── launch.json
│   ├── settings.json
│   ├── tasks.json
│   └── sudo_gdb.sh
├── .zed/                    # Zed 配置模板
│   └── debug.json
├── setup_all.bash           # 一键安装（入口）
├── install.bash             # 项目初始化（newproj 入口）
├── .gitignore
├── README.md
└── LICENSE
```

---

## 常见问题

**Q: conan 命令找不到？**

```bash
source ~/.bashrc
# 或
$HOME/.local/bin/conan --version
```

**Q: perf 提示权限不足？**

脚本会自动检测并请求 sudo。若需永久允许非 root 采样：

```bash
sudo sh -c 'echo -1 > /proc/sys/kernel/perf_event_paranoid'
# 永久：写入 /etc/sysctl.conf 中 kernel.perf_event_paranoid = -1
```

**Q: 火焰图为空（大小 < 500 bytes）？**

检查是否有足够采样数据，尝试调低采样频率或延长采样时间。若程序含大量 I/O 等待，用 `-m` 手动模式在程序活跃期间采样。

**Q: ASan 和 TSan 能同时开吗？**

不能，脚本和 CMake 都会报错阻止。

**Q: TSan 下程序无法运行 / 启动即崩溃？**

TSan 需要大块连续虚拟内存，和系统的 ASLR（地址随机化）冲突。运行时关闭 ASLR：

```bash
setarch $(uname -m) -R ./build/app
```

**Q: 新增/删除了 src/ 下的源文件，编译没生效？**

CMakeLists.txt 使用了 `CONFIGURE_DEPENDS` 自动检测，通常无需手动操作。如遇异常，删除 `build/` 重新编译。

**Q: 没有网络时如何编译测试？**

CPM.cmake 首次构建时把 GoogleTest / Google Benchmark 拉取到 `~/.cache/cpm`（`CPM_SOURCE_CACHE`），下载一次之后所有项目离线可用。首次构建需联网；也可以先在有网环境跑一次 `./my_build.bash test` 预热缓存。

**Q: 怎么看 CPM 装了哪些包、什么版本？**

不需要额外文件——所有依赖都用 `GIT_TAG` 钉死了版本，声明文件本身就是清单：

- 普通库 → `cmake/Dependencies.cmake`
- 测试框架/基准 → `tests/CMakeLists.txt`

快速查看：
```bash
grep -E "GITHUB_REPOSITORY|GIT_TAG" cmake/Dependencies.cmake tests/CMakeLists.txt
```

**Q: 添加库目录后 clangd 不提示但编译正常？**

CMakeLists.txt 使用 `GLOB_RECURSE`，只有存在对应 .h 的 .cpp 才会被加入编译（clangd 同步于编译列表）。

---

## 依赖要求

- Ubuntu 22.04+ / WSL2
- `sudo` 权限（安装阶段）
- 网络连接（首次下载工具链和依赖）

### VS Code 扩展

使用 VS Code 调试需安装以下扩展：

| 扩展 | ID | 必需 | 用途 |
|------|------|:--:|------|
| clangd | `llvm-vs-code-extensions.vscode-clangd` | ✓ | 代码补全、跳转、格式化 |
| CMake Tools | `ms-vscode.cmake-tools` | ✓ | CMake 集成、F5 调试 |
| C++ DevTools | `ms-vscode.cpp-devtools` | ★ | MS 官方 C++ 扩展，符号/性能分析 |
| C++ Debug | `kylinideteam.cppdebug` | ★ | GDB 调试增强 |
| TestMate C++ | `matepek.vscode-catch2-test-adapter` | ★ | 测试资源管理器（GoogleTest/Catch2 通用） |
| Doxygen | `cschlosser.doxdocgen` | | 自动生成 Doxygen 注释 |
| Log Viewer | `berublan.vscode-log-viewer` | | `out/logs/*.log` 日志监控 |

> ✓ 必需 ｜ ★ 强烈推荐 ｜ 无标记 = 可选
>
> 装完 `clangd` 后禁用 VS Code 内置 C++ 扩展（`ms-vscode.cpptools`），避免冲突。C++ DevTools 不冲突，可共存。

---

## 许可

本项目基于 [木兰宽松许可证 第2版 (MulanPSL2)](http://license.coscl.org.cn/MulanPSL2) 发布。
