#!/bin/bash
set -e

BASE_SETTINGS_DIR="${BASE_SETTINGS_DIR:-$HOME/base_settings}"

echo "============================================"
echo "  base_settings 一键安装"
echo "============================================"
echo ""

# 提示检查镜像源（国内网络建议换源，但允许跳过）
_mirror_warn=false
if [ -f /etc/apt/sources.list ] && grep -q 'archive.ubuntu.com\|ports.ubuntu.com' /etc/apt/sources.list 2>/dev/null; then
    _mirror_warn=true
elif [ -f /etc/apt/sources.list.d/ubuntu.sources ] && grep -q 'archive.ubuntu.com\|ports.ubuntu.com' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null; then
    _mirror_warn=true
fi
if $_mirror_warn; then
    echo "⚠️  检测到 apt 使用官方源，国内可能较慢"
    echo "   换源: sudo ${BASE_SETTINGS_DIR}/scripts/setup_mirror.bash"
    echo "   继续: 直接按 Enter"
    echo "   取消: Ctrl+C"
    read -r _ 2>/dev/null || true
fi

export BASE_SETTINGS_DIR

echo "→ 1/3 基础工具"
"${BASE_SETTINGS_DIR}/scripts/basic_install.bash"
echo ""

echo "→ 2/3 Conan"
"${BASE_SETTINGS_DIR}/scripts/conan_install.bash"
echo ""

echo "→ 3/3 perf + FlameGraph"
"${BASE_SETTINGS_DIR}/scripts/perf_install.bash"
echo ""

echo "============================================"
echo "  全部安装完成"
echo "============================================"
echo ""

# ---- 配置 ~/.bashrc（只写一次，不重复）----
if ! grep -q "BASE_SETTINGS_DIR" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << BASHRC_EOF

# base_settings
export BASE_SETTINGS_DIR="${BASE_SETTINGS_DIR}"
alias newproj='\$BASE_SETTINGS_DIR/install.bash'
BASHRC_EOF
    echo "✅ 已配置 ~/.bashrc（BASE_SETTINGS_DIR + newproj 别名）"
    echo "   执行 source ~/.bashrc 后生效"
else
    echo "~/.bashrc 已配置，跳过"
fi

echo ""
echo "  conan 不可用? source ~/.bashrc"
echo "  perf 非 root? sudo sh -c 'echo -1 > /proc/sys/kernel/perf_event_paranoid'"
