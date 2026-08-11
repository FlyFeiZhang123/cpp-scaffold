#!/bin/bash
set -e

echo "=== 安装 Conan 2.x ==="

if command -v conan &>/dev/null; then
    echo "Conan 已安装: $(conan --version)"
    exit 0
fi

# uv 比 pipx 快且干净（需先装: curl -LsSf https://astral.sh/uv/install.sh | sh）
if command -v uv &>/dev/null; then
    uv tool install conan
else
    echo "错误: 未找到 uv，请先安装 uv 再运行本脚本"
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

echo ""
echo "✅ Conan 安装完成"
