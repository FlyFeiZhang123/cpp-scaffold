# bash completion for bench_use.bash
# 共用的 _sc_* 动作在 completion_lib.bash（同目录，由 ~/.bashrc 的循环一并加载）
_bench_use() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    local cword="${COMP_CWORD}"

    case "$prev" in
        --out)
            _sc_files "out/bench" '\.json$' "$cur"
            return
            ;;
        --bind|--repeat|--filter)
            COMPREPLY=()
            return
            ;;
    esac

    # --compare：补全两个 JSON 文件（$prev=--compare 是第一个，$prev 是文件时是第二个）
    if [[ "$prev" == "--compare" || "${COMP_WORDS[cword-2]}" == "--compare" ]]; then
        # 优先 out/bench/，那里一个都没有才退回当前目录
        _sc_files "out/bench" '\.json$' "$cur"
        [ ${#COMPREPLY[@]} -eq 0 ] && _sc_files "." '\.json$' "$cur"
        return
    fi

    _sc_words "--json --compare --list --out --bind --filter --repeat --help" "$cur"
}
complete -F _bench_use bench_use.bash ./bench_use.bash
