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

# uv 装完 shim 落在 ~/.local/bin，但那目录未必在当前 PATH 里 —— 上面那段 PATH 补丁
# 只在「uv 也是本次新装」时才跑。以前这里直接就打印 ✅，于是「装上了但找不到」
# 也照样退出 0，等用户敲 conan 时才发现。basic_install.bash 有验证块，这里补上。
_TOOL_BIN="${UV_TOOL_BIN_DIR:-$HOME/.local/bin}"
export PATH="$_TOOL_BIN:$PATH"
if ! command -v conan &>/dev/null; then
    echo "错误: conan 装好了但不在 PATH 上（试 $_TOOL_BIN/conan）" >&2
    exit 1
fi

echo ""
echo "✅ Conan 安装完成: $(conan --version)"
