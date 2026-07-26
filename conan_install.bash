#!/bin/bash
set -e

echo "=== 安装 Conan 2.x ==="

if command -v conan &>/dev/null; then
    echo "Conan 已安装: $(conan --version)"
    exit 0
fi

sudo apt install -y pipx
pipx install conan
pipx ensurepath

echo ""
echo "✅ Conan 安装完成"
echo "   如命令不可用，请执行: source ~/.bashrc"
