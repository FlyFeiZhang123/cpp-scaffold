#!/bin/bash
set -e

echo "=== 安装基础开发工具 ==="
sudo apt update
# 编译 + 构建 + 调试
sudo apt install -y gcc g++ cmake ninja-build gdb
# 语言服务器 + 格式化
sudo apt install -y clangd clang-format
# 内存泄漏 / cache miss / 堆分析
sudo apt install -y valgrind
# 文档生成 + 调用图
sudo apt install -y doxygen graphviz
# 编译缓存，加速重复编译
sudo apt install -y ccache
# perf 的 PMU 硬件计数器依赖
sudo apt install -y libpfm4-dev

# 限制 ccache 缓存大小（默认 5GB 无上限，避免撑满磁盘）
ccache --max-size=10G

echo ""
echo "=== 验证安装 ==="
cmake  --version | head -1
g++    --version | head -1
clangd --version | head -1
valgrind --version | head -1
echo ""
echo "✅ 基础工具安装完成"
