# bash completion for perf_use.bash
_perf_use() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    local already="${COMP_WORDS[*]}"

    case "$prev" in
        -t|--time|-f|--freq)   COMPREPLY=(); return ;;
        -d|--dir)               COMPREPLY=($(compgen -d -- "$cur")); return ;;
    esac

    [[ "$cur" == --port=* ]] && { COMPREPLY=(); return; }

    if [[ "$already" =~ --serve ]]; then
        COMPREPLY=($(compgen -W "--port= -d --dir -h --help" -- "$cur"))
        return
    fi

    COMPREPLY=($(compgen -W "--serve --time --manual --wrap --dir --freq --port= --help -t -m -w -d -f -h" -- "$cur"))
}
complete -F _perf_use perf_use.bash ./perf_use.bash
