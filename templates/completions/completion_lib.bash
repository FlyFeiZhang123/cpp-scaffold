# cpp-scaffold 补全脚本共用的动作。
#
# 这个目录由 ~/.bashrc 里的一段 source 循环整目录加载（见 setup_all.bash），所以本文件
# 只定义函数、加载时不执行任何东西。补全函数要等用户按 Tab 才被调用，因此它排在别的
# 补全脚本之前还是之后都无所谓 —— 不存在「定义晚于使用」。

# 选项补全：$1 = 空格分隔的候选，$2 = 当前词。
#
# 用 mapfile 而不是 COMPREPLY=($(compgen ...))：后者按空白切分，候选里带空格的文件名
# 会被切成两条（实测 "my dir" 补成 <my> <dir> 两条）；mapfile 按行读，原样保留。
#
# 另外两种「空」不是一回事，混用会凭空多出一条空候选：`< <(compgen ...)` 无输出时
# mapfile 给的是**零元素数组**，而 `mapfile <<< ""` 给的是**一个空元素**。所以空结果
# 就让命令替换自己空着，别用 here-string 喂空串。
_sc_words() {
    mapfile -t COMPREPLY < <(compgen -W "$1" -- "$2")
}

# 补全某个目录里的文件：$1 = 目录（"." 表示当前目录），$2 = 后缀正则（空串 = 不过滤），
# $3 = 当前词。
#
# 目录不存在就是空候选，不退回当前目录 —— 退回会让人以为自己站在另一个目录里敲。
_sc_files() {
    local dir="$1" pat="$2" cur="$3"
    COMPREPLY=()
    [ -d "$dir" ] || return 0
    mapfile -t COMPREPLY < <(cd "$dir" && compgen -f -- "$cur" | grep -E -- "$pat")
}

# 补全目录名（perf_use 的 -d/--dir）：$1 = 当前词，$2 = 在哪个目录下找（默认当前目录）
_sc_dirs() {
    local cur="$1" dir="${2:-.}"
    COMPREPLY=()
    [ -d "$dir" ] || return 0
    mapfile -t COMPREPLY < <(cd "$dir" && compgen -d -- "$cur")
}

# 不补尾随空格 —— 给 --port= / --exe-src= 这类「后面还得接着敲值」的候选用。
# 2>/dev/null：compopt 只在补全上下文里有意义，别处调用会报错。
_sc_nospace() {
    compopt -o nospace 2>/dev/null || true
}
