# bash completion for perf_use.bash
# 共用的 _sc_* 动作在 completion_lib.bash（同目录，由 ~/.bashrc 的循环一并加载）
_perf_use() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    local already="${COMP_WORDS[*]}"

    case "$prev" in
        -t|--time|-f|--freq)   COMPREPLY=(); return ;;
        -d|--dir)              _sc_dirs "$cur"; return ;;
    esac

    [[ "$cur" == --port=* ]] && { COMPREPLY=(); return; }

    if [[ "$already" =~ --serve ]]; then
        _sc_words "--port= -d --dir -h --help" "$cur"
        [[ "${COMPREPLY[0]}" == --port= ]] && _sc_nospace
        return
    fi

    _sc_words "--serve --time --manual --wrap --dir --freq --port= --help -t -m -w -d -f -h" "$cur"
    [[ "${COMPREPLY[0]}" == --port= ]] && _sc_nospace
}
complete -F _perf_use perf_use.bash ./perf_use.bash
