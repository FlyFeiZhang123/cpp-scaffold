#!/bin/bash
set -e

BASE_SETTINGS_DIR="${BASE_SETTINGS_DIR:-$HOME/cpp-scaffold}"

echo "============================================"
echo "  cpp-scaffold 一键安装"
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

# doctest / Google Benchmark 不再单独克隆 —— 由 CPM.cmake 在首次构建时拉取到
# ~/.cache/cpm（CPM_SOURCE_CACHE），下载一次 → 之后所有项目离线可用。

echo "============================================"
echo "  全部安装完成"
echo "============================================"
echo ""

# ---- 配置 ~/.bashrc（只写 BASE_SETTINGS_DIR + source 循环；别名等设置由 settings_use.bash 提供）----
if ! grep -q "BASE_SETTINGS_DIR" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << BASHRC_EOF

# cpp-scaffold
export BASE_SETTINGS_DIR="${BASE_SETTINGS_DIR}"

# 补全 + 环境设置（settings_use.bash / my_build.bash / bench_use.bash / perf_use.bash）
for f in "\$BASE_SETTINGS_DIR"/templates/completions/*.bash; do
    [ -f "\$f" ] && source "\$f"
done
BASHRC_EOF
    echo "✅ 已配置 ~/.bashrc（BASE_SETTINGS_DIR + source 循环）"
    echo "   执行 source ~/.bashrc 后生效"
else
    echo "~/.bashrc 已有基础配置，跳过"
    if ! grep -q "completions" ~/.bashrc 2>/dev/null; then
        cat >> ~/.bashrc << BASHRC_EOF

# cpp-scaffold — source 循环（补全 + 环境设置）
for f in "\$BASE_SETTINGS_DIR"/templates/completions/*.bash; do
    [ -f "\$f" ] && source "\$f"
done
BASHRC_EOF
        echo "   ↳ 已补写 source 循环配置"
    fi
fi

echo ""
echo "  conan 不可用? source ~/.bashrc"
echo "  perf 非 root? sudo sh -c 'echo -1 > /proc/sys/kernel/perf_event_paranoid'"
