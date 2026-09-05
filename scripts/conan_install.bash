#!/bin/bash
set -e

echo "=== 安装 Conan 2.x ==="

if command -v conan &>/dev/null; then
    echo "Conan 已安装: $(conan --version)"
    exit 0
fi

# uv 比 pipx 快且干净；缺失时直接装，不再需要手动步骤
if ! command -v uv &>/dev/null; then
    echo "未找到 uv，正在安装 uv ..."
    export UV_INSTALL_DIR="${UV_INSTALL_DIR:-$HOME/.local/bin}"  # 装到用户目录，免 sudo
    if command -v curl &>/dev/null; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    elif command -v wget &>/dev/null; then
        wget -qO- https://astral.sh/uv/install.sh | sh
    else
        echo "错误: 需要 curl 或 wget 才能安装 uv"; exit 1
    fi
    # 安装脚本不会重载当前 shell 的 PATH，这里手动补上，后续直接可用
    export PATH="$UV_INSTALL_DIR:$PATH"
    command -v uv &>/dev/null || {
        echo "错误: uv 安装失败，请手动执行: curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    }
fi

uv tool install conan

echo ""
echo "✅ Conan 安装完成"
