#!/bin/bash
set -e

echo "=== 安装 perf + FlameGraph ==="

# 安装 perf（ubuntu 官方包，无需编译内核）
sudo apt install -y linux-tools-common linux-tools-generic || {
    echo "⚠️  linux-tools-generic 安装失败，尝试安装当前内核版本工具..."
    sudo apt install -y "linux-tools-$(uname -r)" 2>/dev/null || {
        echo "⚠️  perf 安装失败，请手动安装: sudo apt install linux-tools-$(uname -r)"
        echo "   如当前内核无对应工具包，可尝试升级内核: sudo apt upgrade"
    }
}

# 验证 perf
if command -v perf &>/dev/null; then
    perf --version | head -1
else
    echo "⚠️  perf 未成功安装，跳过 FlameGraph"
    exit 0
fi

# 安装 FlameGraph
if [ -d ~/FlameGraph ]; then
    echo "FlameGraph 已存在，跳过"
else
    echo "克隆 FlameGraph..."
    git clone --depth 1 git@github.com:brendangregg/FlameGraph.git ~/FlameGraph 2>/dev/null || \
    git clone --depth 1 https://github.com/brendangregg/FlameGraph.git ~/FlameGraph
    echo "FlameGraph → ~/FlameGraph"
fi

echo ""
echo "✅ perf + FlameGraph 安装完成"
echo "   如需非 root 采样: sudo sh -c 'echo -1 > /proc/sys/kernel/perf_event_paranoid'"
