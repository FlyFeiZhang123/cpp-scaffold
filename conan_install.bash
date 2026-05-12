#!/bin/bash
set -e

# 更新并安装 pipx（需要 sudo）
sudo apt update
sudo apt install -y pipx

# 以下操作不需要 root
pipx install conan
pipx ensurepath

# 提示用户手动刷新 PATH
echo "Please run 'source ~/.bashrc' or restart your terminal to use 'conan'."

# 验证（使用完整路径）
$HOME/.local/bin/conan --version