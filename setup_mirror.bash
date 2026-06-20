#!/bin/bash
set -e

ARCH=$(uname -m)
UBUNTU_CODENAME=$(lsb_release -cs)
echo "=== 架构: $ARCH, 版本: $UBUNTU_CODENAME ==="

# 备份并移除所有旧的源配置，避免重复
[ -f /etc/apt/sources.list ] && sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%Y%m%d_%H%M%S)
[ -f /etc/apt/sources.list.d/ubuntu.sources ] && sudo cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak.$(date +%Y%m%d_%H%M%S) && sudo rm -f /etc/apt/sources.list.d/ubuntu.sources

if [ "$ARCH" = "x86_64" ]; then
    echo "=== x86_64 架构，配置阿里云镜像 ==="
    sudo tee /etc/apt/sources.list > /dev/null << EOF
deb http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF
elif [ "$ARCH" = "aarch64" ]; then
    echo "=== ARM64 架构，配置官方 ports 源 ==="
    sudo tee /etc/apt/sources.list > /dev/null << EOF
deb http://ports.ubuntu.com/ubuntu-ports ${UBUNTU_CODENAME} main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports ${UBUNTU_CODENAME}-backports main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF
else
    echo "⚠️ 未知架构: $ARCH，使用官方源"
    sudo tee /etc/apt/sources.list > /dev/null << EOF
deb http://archive.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF
fi

# 清理旧缓存并更新
sudo apt clean
sudo rm -rf /var/lib/apt/lists/*
sudo mkdir -p /var/lib/apt/lists/partial
sudo apt update

echo "✅ 配置完成，无重复源。"

#针对ubuntu24.04文件改动，如果想要消除警告可以执行下面这行，不影响使用
# sudo mv /etc/apt/sources.list.d/ubuntu.sources.bak.* /etc/apt/ 2>/dev/null || true
