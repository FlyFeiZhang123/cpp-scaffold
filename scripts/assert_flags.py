#!/usr/bin/env python3
"""断言编译开关真的落进了**每一个** TU 的命令行。

用法: python3 scripts/assert_flags.py <档位>
档位: ASan | UBSan | TSan | None | release

读当前目录下的 build/compile_commands.json（构建目录根上的软链接，my_build.bash 建的）。

为什么是全称断言而不是 grep：查产物时「文件里搜得到」和「每个 TU 都带」是两回事，
而踩过的坑恰好落在两者之间 —— 老写法只覆盖了库和 exe，tests/CMakeLists.txt 建的两个
target 一个 flag 都没吃到，`grep -q` 照样绿。尺子量不出那个 bug，等于没量。
"""
import json
import pathlib
import sys

# 档位 → 本项目每个 TU 都必须带的 flag。写成列表而非单个：-fno-sanitize-recover=all
# 就是当初被静默丢掉的那一个（apply_flags 只认第一个形参），少了它 UBSan 变成
# 「打印一行然后继续跑」、退出码 0，这条腿永远不会红 —— 只验 -fsanitize=undefined
# 等于把同一次事故再放一遍。
#
# 匹配是子串（`flag not in 命令行`），所以 "-flto" 同时认 -flto=thin（clang）和
# -flto=auto（gcc）：LTO 走 CMake 的 IPO 属性，具体发哪个由 CMake 按编译器决定。
NEED = {
    "ASan":    ["-fsanitize=address", "-O1"],
    "UBSan":   ["-fsanitize=undefined", "-fno-sanitize-recover=all"],
    "TSan":    ["-fsanitize=thread", "-O1"],
    "None":    [],
    "release": ["-O3", "-DNDEBUG", "-flto", "-fopenmp"],
}
# 这两档反过来查：一个 TU 都不该有 sanitizer
NO_SANITIZER = ("None", "release")


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] not in NEED:
        sys.exit(f"用法: {sys.argv[0]} <{'|'.join(NEED)}>")
    tier = sys.argv[1]

    path = pathlib.Path("build/compile_commands.json")
    if not path.is_file():
        sys.exit(f"找不到 {path} —— 先构建，或者 cwd 不对")
    entries = json.loads(path.read_text())

    # 只挑本项目自己的 TU。依赖同样吃到了这些 flag（那是插桩一致性要求的），
    # 但「依赖有没有带上」不是这里要验的东西，混进来只会让失败信息变成一屏噪声。
    #
    # 判据用「在项目目录内 且 不在 _deps 下」，不是猜目录名：CPM 的源码落在
    # $HOME/.cache/cpm/<包>/<hash>/（Dependencies.cmake:7 的 CPM_SOURCE_CACHE），
    # 在项目目录外，而 file 字段记的是**源码**路径 —— 光看有没有 "_deps" 会漏掉
    # 这一整类（_deps 只是构建目录里 FetchContent 的落点，CI 与本地都可能不同）。
    root = pathlib.Path.cwd().resolve()

    def is_ours(path: str) -> bool:
        p = pathlib.Path(path).resolve()
        return p.is_relative_to(root) and "_deps" not in p.parts

    def cmd_of(e):
        return e.get("command") or " ".join(e.get("arguments", []))

    ours = [(e["file"], cmd_of(e)) for e in entries if is_ours(e["file"])]
    if not ours:
        sys.exit(f"{path} 里没有本项目自己的 TU —— 产物不对")

    if tier in NO_SANITIZER:
        bad = [f for f, c in ours if "-fsanitize" in c]
        if bad:
            sys.exit(f"{tier} 档不该有 sanitizer，但 {len(bad)}/{len(ours)} 个 TU 带了: {bad}")

    for flag in NEED[tier]:
        bad = [f for f, c in ours if flag not in c]
        if bad:
            sys.exit(f"{len(bad)}/{len(ours)} 个 TU 没吃到 {flag}: {bad}")

    flags = " ".join(NEED[tier]) or "(无 sanitizer)"
    print(f"{tier}: {len(ours)} 个 TU 全部带齐 {flags}")


main()
