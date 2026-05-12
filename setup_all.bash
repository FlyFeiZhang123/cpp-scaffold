#!/bin/bash

BASE_SETTINGS_DIR="$HOME/base_settings"

# 直接执行，不添加 sudo
${BASE_SETTINGS_DIR}/basic_install.bash
${BASE_SETTINGS_DIR}/conan_install.bash
${BASE_SETTINGS_DIR}/perf_install.bash

echo "所有工具安装完成。请注意："
echo "  - 如果 conan 命令不可用，请执行 'source ~/.bashrc' 或重启终端。"
echo "  - 使用 perf 时若需要非 root 采样，请考虑设置 kernel.perf_event_paranoid=-1（见 perf_install.bash 提示）。"