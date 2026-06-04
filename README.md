```markdown
# base_settings — C++ 项目脚手架

一套现代 C++ 开发环境模板，一键装环境、一键建项目、一键编译调试。

---

## 功能一览

| 功能     | 工具                | 说明                                    |
| -------- | ------------------- | --------------------------------------- |
| 构建系统 | CMake 3.20+ + Ninja | 支持 Debug / Release / Sanitizer 多配置 |
| 包管理   | Conan 2.x           | 可选，通过 `conanfile.txt` 开启         |
| 代码补全 | clangd              | VS Code 配置已内置                      |
| 单元测试 | doctest             | FetchContent 自动获取，支持离线缓存     |
| 内存检测 | ASan / TSan / UBSan | 编译参数一键切换                        |
| 内存泄漏 | Valgrind            | 兼容 dwarf-4 调试信息                   |
| 性能分析 | perf + FlameGraph   | 一键生成火焰图                          |
| 文档生成 | Doxygen             | 配置模板已含                            |

---

## 快速开始

### 1. 安装环境（只需一次）

```bash
git clone <你的仓库地址> ~/base_settings
cd ~/base_settings
./setup_all.bash
```

> 国内网络建议先执行 `./setup_mirror.bash` 切换 apt 源。
注：务必看清是否是ubuntu22.04/ubuntu24.04系列，其他linux系统无法保证
### 2. 配置快捷命令（推荐）

在 `~/.bashrc` 末尾添加：

```bash
export BASE_SETTINGS_DIR="$HOME/base_settings"
alias newproj='$BASE_SETTINGS_DIR/install.bash'
```

然后 `source ~/.bashrc`。

### 3. 创建新项目

```bash
# 基本项目
newproj my_project my_app

# 需要 Conan 依赖管理
newproj my_project my_app y
```

会在当前目录生成：
```
my_project/
├── CMakeLists.txt
├── conanfile.txt          # 如果指定了 y
├── .gitignore
├── include/
├── src/
├── tests/
│   ├── CMakeLists.txt
│   └── test_main.cpp
├── example/
│   └── main.cpp
├── .vscode/               # VS Code 配置（含 clangd、调试 launch）
├── my_build.bash          # 构建脚本
├── perf_use.bash          # 性能分析脚本
└── Doxyfile               # 文档配置
```

> 库名自动跟随项目名，例如 `my_project_lib`。

### 4. 编译项目

```bash
cd my_project

# 默认 Debug + ASan
./my_build.bash

# Release 模式
./my_build.bash release

# 指定入口文件（example/ 目录下）
./my_build.bash --exe-src=main.cpp

# 组合使用
./my_build.bash asan ubsan release

# 编译并运行测试
./my_build.bash test
```

### 5. 运行与调试

```bash
# 运行可执行文件（名称取决于创建项目时的参数）
./build/<EXECUTABLE_NAME>

# Valgrind 检测内存泄漏
valgrind --leak-check=full ./build/<EXECUTABLE_NAME>

# 性能采样 + 火焰图
./perf_use.bash ./build/<EXECUTABLE_NAME>
# 输出: perf/flamegraph.svg
```

---

## 构建选项速查

| 参数                | 效果                                   |
| ------------------- | -------------------------------------- |
| `asan`              | 开启 AddressSanitizer                  |
| `tsan`              | 开启 ThreadSanitizer（与 asan 互斥）   |
| `ubsan`             | 开启 UndefinedBehaviorSanitizer        |
| `valgrind`          | 生成 dwarf-4 调试信息（兼容 Valgrind） |
| `release` / `debug` | 构建类型，默认 debug                   |
| `--exe-src=<file>`  | 指定 `example/` 下的入口源文件         |
| `test`              | 编译后运行 ctest                       |

---

## 项目结构（模板仓库）

```
base_settings/
├── .vscode/                # VSCode 配置
├── .zed/                   # Zed 配置
├── basic_install.bash      # 基础工具安装（gcc、cmake、clangd、valgrind 等）
├── conan_install.bash      # Conan 2.x 安装
├── perf_install.bash       # perf + FlameGraph 安装
├── setup_all.bash          # 一键执行以上三个安装脚本
├── setup_mirror.bash       # 切换中科大 apt 源（支持 22.04/24.04）
├── install.bash            # 项目初始化脚本（被 newproj 调用）
├── my_build.bash           # 项目构建脚本
├── perf_use.bash           # 性能分析脚本
├── CMakeLists.txt          # CMake 模板
├── conanfile.txt           # Conan 模板
├── .gitignore              # Git 忽略模板
├── example/
│   └── main.cpp            # 示例入口
├── tests/
│   ├── CMakeLists.txt      # 测试子目录 CMake
│   └── test_main.cpp       # doctest 示例
└── Doxyfile                # Doxygen 配置模板
```

---

## 常见问题

**Q: `conan` 命令找不到？**
```bash
source ~/.bashrc
# 或直接使用完整路径
$HOME/.local/bin/conan --version
```

**Q: perf 需要 root？**
```bash
sudo sh -c 'echo -1 > /proc/sys/kernel/perf_event_paranoid'
# 永久生效可写入 /etc/sysctl.conf
```

**Q: ASan 和 TSan 能同时开吗？**
不能，脚本和 CMake 都会报错阻止。

**Q: 新增/删除了 `src/` 下的源文件，编译没生效？**
`CMakeLists.txt` 使用了 `CONFIGURE_DEPENDS` 自动检测文件变化，通常无需手动操作。如遇异常，删除 `build/` 重新编译即可。

**Q: 没有网络时如何编译测试？**
将 doctest 源码放在 `~/base_settings/doctest-offline/` 目录下，CMake 会自动使用本地缓存，不再从网络拉取。

**Q: 添加库目录后，clangd未提示，但是编译成功？**
`CMakeLists.txt` 中的配置使得必须有对应cpp的.h 才会被加入编译，否则不会管这个目录的clangd提示以及相关功能。

---

## 依赖要求

- Ubuntu 22.04+ / WSL2
- 有 `sudo` 权限（安装阶段需要）
- 网络连接（首次下载工具链和依赖）

---

## 许可
```
