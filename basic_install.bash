#!/bin/bash
set -e

echo "Installing basic tools..."
sudo apt update
sudo apt install -y gcc g++ ninja-build gdb cmake clangd clang-format 

echo "Installing optional tools..."
sudo apt install -y doxygen graphviz ccache

echo "Installing Valgrind..."
sudo apt install -y valgrind

# 验证安装
if valgrind --version; then
    echo "Valgrind installed successfully."
else
    echo "Valgrind installation failed."
    exit 1
fi