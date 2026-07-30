#!/bin/bash
set -e

ARCH=$(uname -m)
UBUNTU_CODENAME=$(lsb_release -cs)
UBUNTU_VERSION=$(lsb_release -rs)

echo "=== 架构: $ARCH, 版本: $UBUNTU_CODENAME ($UBUNTU_VERSION) ==="

# ===== 1. 根据架构选择镜像 URL =====
# x86_64 用 ubuntu/, aarch64 用 ubuntu-ports/
case "$ARCH" in
    x86_64)
        ALIYUN_URL="http://mirrors.aliyun.com/ubuntu/"
        TSINGHUA_URL="http://mirrors.tuna.tsinghua.edu.cn/ubuntu/"
        ;;
    aarch64)
        ALIYUN_URL="http://mirrors.aliyun.com/ubuntu-ports/"
        TSINGHUA_URL="http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/"
        ;;
    *)
        echo "⚠️ 未知架构: $ARCH，使用官方源"
        ALIYUN_URL="http://archive.ubuntu.com/ubuntu/"
        TSINGHUA_URL=""
        ;;
esac

# ===== 2. 备份函数 =====
# 备份到 /etc/apt/ 目录下，避免 sources.list.d/ 里出现非 .list/.sources 文件触发的 apt 警告
backup_file() {
    local f="$1"
    if [ -f "$f" ]; then
        local bak="/etc/apt/$(basename "$f").bak.$(date +%Y%m%d_%H%M%S)"
        sudo cp "$f" "$bak"
        echo "  已备份: $f -> $bak"
    fi
}

# ===== 3. 按 Ubuntu 版本选择格式并写入 =====
if dpkg --compare-versions "$UBUNTU_VERSION" ge "24.04"; then
    # ---- 24.04+ : DEB822 格式 (ubuntu.sources) ----
    # 多 URI 是真正的 fallback：apt 按序尝试，阿里云挂了自动走清华
    echo "=== 使用 DEB822 格式 (24.04+) ==="
    echo "    主源: 阿里云"
    echo "    副源: 清华"

    SOURCES_FILE="/etc/apt/sources.list.d/ubuntu.sources"

    # 备份并注释掉旧格式 sources.list，避免与 ubuntu.sources 冲突
    if [ -f /etc/apt/sources.list ]; then
        backup_file /etc/apt/sources.list
        # 只注释未注释的 deb 行，已注释的不动
        sudo sed -i 's/^deb /#deb /' /etc/apt/sources.list
        echo "  已注释 /etc/apt/sources.list 中的旧格式条目"
    fi

    backup_file "$SOURCES_FILE"

    sudo tee "$SOURCES_FILE" > /dev/null << EOF
# 由 setup_mirror.bash 生成 ($(date +%Y-%m-%d))
# 架构: $ARCH  版本: $UBUNTU_CODENAME ($UBUNTU_VERSION)
# URIs 按优先级排列：阿里云（主）→ 清华（副）
Types: deb
URIs: ${ALIYUN_URL}
      ${TSINGHUA_URL}
Suites: ${UBUNTU_CODENAME} ${UBUNTU_CODENAME}-updates ${UBUNTU_CODENAME}-backports ${UBUNTU_CODENAME}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

else
    # ---- 22.04 : 老格式 (sources.list) ----
    # 老格式不支持真正的 fallback，多写只会重复拉索引
    # 所以只写阿里云主源，需要清华请手动替换 URL
    echo "=== 使用传统格式 (22.04) ==="
    echo "    主源: 阿里云（老格式不支持副源，如需清华请手动替换 URL）"

    SOURCES_FILE="/etc/apt/sources.list"

    # 清理掉 24.04 才有的 ubuntu.sources（如果跨版本升级残留）
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
        backup_file /etc/apt/sources.list.d/ubuntu.sources
        sudo rm -f /etc/apt/sources.list.d/ubuntu.sources
        echo "  已移除残留的 ubuntu.sources"
    fi

    backup_file "$SOURCES_FILE"

    sudo tee "$SOURCES_FILE" > /dev/null << EOF
# 由 setup_mirror.bash 生成 ($(date +%Y-%m-%d))
# 架构: $ARCH  版本: $UBUNTU_CODENAME ($UBUNTU_VERSION)
# 主源: 阿里云
# 如需切换清华源，将下方 mirrors.aliyun.com 替换为 mirrors.tuna.tsinghua.edu.cn
deb ${ALIYUN_URL} ${UBUNTU_CODENAME} main restricted universe multiverse
deb ${ALIYUN_URL} ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb ${ALIYUN_URL} ${UBUNTU_CODENAME}-backports main restricted universe multiverse
deb ${ALIYUN_URL} ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF

fi

# ===== 4. 清理缓存并更新 =====
echo ""
echo "=== 清理缓存 ==="
sudo apt clean
sudo rm -rf /var/lib/apt/lists/*
sudo mkdir -p /var/lib/apt/lists/partial

echo "=== 更新源 ==="
sudo apt update

echo ""
echo "✅ 镜像源配置完成"
echo "   架构: $ARCH"
echo "   版本: $UBUNTU_CODENAME ($UBUNTU_VERSION)"
echo "   格式: $(dpkg --compare-versions "$UBUNTU_VERSION" ge "24.04" && echo "DEB822" || echo "传统")"
echo "   主源: 阿里云"
dpkg --compare-versions "$UBUNTU_VERSION" ge "24.04" && echo "   副源: 清华（自动 fallback）"
