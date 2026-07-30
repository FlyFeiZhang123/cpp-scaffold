# base_settings — C++ 项目脚手架

一套现代 C++ 开发环境模板，一键装环境、一键建项目、一键编译调试。

---

## 功能一览

| 功能     | 工具                     | 说明                                    |
| -------- | ------------------------ | --------------------------------------- |
| 构建系统 | CMake 3.20+ + Ninja/Make | 支持 Debug / Release / Sanitizer 多配置 |
| 包管理   | Conan 2.x                | 可选，通过 `conanfile.txt` 开启         |
| 代码补全 | clangd                   | VS Code / Zed 配置已内置                |
| 代码格式化 | clang-format + clang-tidy | 模板自带                               |
| 单元测试 | doctest                  | FetchContent 自动获取，支持离线缓存     |
| 内存检测 | ASan / TSan / UBSan      | 编译参数一键切换                        |
| 内存泄漏 | Valgrind                 | 兼容 dwarf-4 调试信息                   |
| 性能分析 | perf + FlameGraph        | 三种采样模式，一键生成火焰图            |
| 文档生成 | Doxygen                  | 配置模板已含                            |

---

## 快速开始

### 1. 安装环境（只需一次）

```bash
git clone https://gitee.com/flyzhang123/base_settings ~/base_settings
cd ~/base_settings

# 国内网络先换源（阿里云 + 清华双源，自动适配 x86_64/ARM64,如果需要的话）
sudo ./scripts/setup_mirror.bash

# 一键安装：gcc、cmake、ninja、clangd、conan、perf、FlameGraph 等
./setup_all.bash
```

> 支持 Ubuntu 22.04 / 24.04 / 26.04，x86_64 和 ARM64 架构。

### 2. 配置快捷命令

`setup_all.bash` 已自动将以下内容写入 `~/.bashrc`：

```bash
export BASE_SETTINGS_DIR="$HOME/base_settings"
alias newproj='$BASE_SETTINGS_DIR/install.bash'
```

新终端或 `source ~/.bashrc` 后即可使用 `newproj` 命令。

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
├── .gitee-ci.yml              # Gitee CI
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
│   └── test_main.cpp
├── example/
│   └── main.cpp
├── .vscode/                 # VS Code 配置（选 v 时）
│   ├── launch.json          #   调试配置（普通 + sudo 两种）
│   ├── settings.json        #   clangd + CMake 配置
│   ├── tasks.json           #   F5 自动编译
│   └── sudo_gdb.sh          #   root 权限调试
├── .zed/                    # Zed 配置（选 z 时）
│   └── debug.json
├── my_build.bash            # 构建脚本
├── perf_use.bash            # 性能分析脚本
└── Doxyfile                 # 文档配置
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

# 编译并运行测试
./my_build.bash test

# WSL2 关闭 -march=native
./my_build.bash no-march

# 链接时优化
./my_build.bash release lto

# 指定入口文件
./my_build.bash --exe-src=main.cpp
```

### 5. 运行与调试

```bash
# 运行
./build/<EXECUTABLE_NAME>

# Valgrind 检测内存泄漏
valgrind --leak-check=full ./build/<EXECUTABLE_NAME>

# 性能采样（默认 wrap 模式，程序结束自动停）
./perf_use.bash ./build/<EXECUTABLE_NAME>

# 采样 30 秒（适合长期运行的程序）
./perf_use.bash ./build/<EXECUTABLE_NAME> -t 30

# 手动按 Enter 停止（适合交互调试）
./perf_use.bash ./build/<EXECUTABLE_NAME> -m

# 浏览器查看火焰图
./perf_use.bash --serve
```

> **调试**：VS Code 中按 `F5` 即可，`launch.json` 已配置 `preLaunchTask` 自动编译。

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
| `valgrind`          | 生成 dwarf-4 调试信息（兼容 Valgrind） |
| `release` / `debug` | 构建类型，默认 Debug                   |
| `--exe-src=<file>`  | 指定 `example/` 下的入口源文件         |
| `test`              | 编译后运行 ctest                       |

---

## 项目结构（模板仓库）

```
base_settings/
├── scripts/                 # 安装脚本
│   ├── setup_mirror.bash    #   apt 换源（阿里云主 + 清华副）
│   ├── basic_install.bash   #   gcc、cmake、ninja、clangd 等
│   ├── conan_install.bash   #   Conan 2.x
│   └── perf_install.bash    #   perf + FlameGraph
├── templates/               # 项目模板（会被复制到新项目）
│   ├── .gitee-ci.yml        #   CI 模板
│   ├── CMakeLists.txt
│   ├── conanfile.txt
│   ├── my_build.bash        #   构建脚本
│   ├── perf_use.bash        #   性能分析
│   ├── Doxyfile
│   ├── example/
│   └── tests/
├── .vscode/                 # VS Code 配置模板
│   ├── launch.json
│   ├── settings.json
│   ├── tasks.json
│   └── sudo_gdb.sh
├── .zed/                    # Zed 配置模板
│   └── debug.json
├── setup_all.bash           # 一键安装（入口）
├── install.bash             # 项目初始化（newproj 入口）
├── .clang-format
├── .clang-tidy
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
setarch $(uname -m) -R ./build/<EXECUTABLE_NAME>
```

**Q: 新增/删除了 src/ 下的源文件，编译没生效？**

CMakeLists.txt 使用了 `CONFIGURE_DEPENDS` 自动检测，通常无需手动操作。如遇异常，删除 `build/` 重新编译。

**Q: 没有网络时如何编译测试？**

将 doctest 源码放在 `~/base_settings/doctest-offline/` 下，CMake 自动使用本地缓存。

**Q: 添加库目录后 clangd 不提示但编译正常？**

CMakeLists.txt 使用 `GLOB_RECURSE`，只有存在对应 .h 的 .cpp 才会被加入编译（clangd 同步于编译列表）。

---

## 依赖要求

- Ubuntu 22.04+ / WSL2
- `sudo` 权限（安装阶段）
- 网络连接（首次下载工具链和依赖）

### VS Code 扩展

使用 VS Code 调试需安装以下扩展：

| 扩展                       | 必需 | 用途                     |
| -------------------------- | :--: | ------------------------ |
| clangd                       |  ✓   | 代码补全、跳转、格式化   |
| CMake Tools                |  ✓   | CMake 集成、F5 调试      |
| Log Viewer                 |      | `logs/*.log` 日志监控    |

> 注意：装完 `vscode-clangd` 后建议禁用 VS Code 内置的 C++ 扩展，避免冲突。

---

## 许可

本项目基于 [木兰宽松许可证 第2版 (MulanPSL2)](http://license.coscl.org.cn/MulanPSL2) 发布。
