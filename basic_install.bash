#!/bin/bash
set -e

echo "=== 安装基础开发工具 ==="
sudo apt update
sudo apt install -y \
    gcc g++ cmake ninja-build gdb \
    clangd clang-format \
    valgrind \
    doxygen graphviz \
    ccache

echo ""
echo "=== 验证安装 ==="
cmake  --version | head -1
g++    --version | head -1
clangd --version | head -1
valgrind --version | head -1
echo ""
echo "✅ 基础工具安装完成"
