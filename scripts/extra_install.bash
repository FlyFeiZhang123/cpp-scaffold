#!/bin/bash
set -e

echo "=== 安装额外开发工具 ==="

sudo apt update
# 堆内存分配分析（命令行 + 纯文本）
sudo apt install -y heaptrack
# heaptrack GUI 可视化（独立包）
sudo apt install -y heaptrack-gui

echo ""
echo "=== 验证安装 ==="
heaptrack --version 2>&1 | head -1 || echo "heaptrack OK"
echo ""
echo "✅ 额外工具安装完成"
