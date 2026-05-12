#!/bin/bash
set -e

# echo "Installing dependencies..."
# sudo apt update
# sudo apt install -y build-essential flex bison \
#     libelf-dev libdw-dev libaudit-dev libnuma-dev \
#     libdebuginfod-dev systemtap-sdt-dev libunwind-dev \
#     libslang2-dev libperl-dev libbabeltrace-dev libpfm4-dev \
#     libtraceevent-dev python3-dev pkg-config libssl-dev libcap-dev

# # 克隆内核源码（如果不存在）
# if [ ! -d ~/WSL2-Linux-Kernel ]; then
#     echo "Cloning WSL2 kernel source..."
#     cd ~
#     git clone --depth 1 https://github.com/microsoft/WSL2-Linux-Kernel.git
# else
#     echo "Kernel source already exists. Skipping clone."
# fi

# # 编译 perf
# cd ~/WSL2-Linux-Kernel/tools/perf
# make clean 2>/dev/null || true
# echo "Compiling perf (this may take a few minutes)..."
# make -j$(nproc)

# # 安装到系统目录（需要 sudo）
# echo "Installing perf to /usr/local/bin..."
# sudo cp perf /usr/local/bin/

# # 验证安装
# if /usr/local/bin/perf --version; then
#     echo "perf installed successfully."
# else
#     echo "perf installation failed."
#     exit 1
# fi

# 可选：配置权限（非 root 采样需要）
echo "If you want to run perf without root, consider setting:"
echo "  sudo sh -c 'echo -1 > /proc/sys/kernel/perf_event_paranoid'"
echo "  (or add it to /etc/sysctl.conf to make it permanent)"

# 安装 FlameGraph（如果不存在）
if [ ! -d ~/FlameGraph ]; then
    echo "Cloning FlameGraph..."
    git clone https://github.com/brendangregg/FlameGraph.git ~/FlameGraph
    echo "FlameGraph cloned to ~/FlameGraph"
else
    echo "FlameGraph already exists. Skipping."
fi

sudo apt update && sudo apt install linux-tools-common linux-tools-generic linux-tools-$(uname -r)