#!/bin/bash
set -e

echo "=== 重置树莓派 Ubuntu 22.04 (ARM64) 软件源到官方 ==="

# 备份当前源
if [ -f /etc/apt/sources.list ]; then
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%Y%m%d_%H%M%S)
    echo "已备份当前源到 /etc/apt/sources.list.bak.*"
fi

# 写入官方 ARM64 源（Ubuntu 22.04 Jammy）
sudo tee /etc/apt/sources.list > /dev/null << 'EOF'
deb http://ports.ubuntu.com/ubuntu-ports jammy main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports jammy-updates main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports jammy-backports main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports jammy-security main restricted universe multiverse
EOF

echo "已写入官方 ports 源。"

# 清理 APT 缓存并更新
echo "清理 APT 缓存..."
sudo apt clean
sudo rm -rf /var/lib/apt/lists/*
sudo mkdir -p /var/lib/apt/lists/partial

echo "更新软件源..."
sudo apt update

echo "✅ 源重置完成。现在可以正常使用 apt 安装/更新软件了。"