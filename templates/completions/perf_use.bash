# bash completion for perf_use.bash
#
# 用 mapfile 而不是 COMPREPLY=($(compgen ...))：后者按空白切分，目录/文件名里带空格
# 会被切成两条（实测 "my dir" 补成 <my> <dir>）；mapfile 按行读，原样保留。
_perf_use() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    local already="${COMP_WORDS[*]}"

    case "$prev" in
        -t|--time|-f|--freq)   COMPREPLY=(); return ;;
        -d|--dir)               mapfile -t COMPREPLY < <(compgen -d -- "$cur"); return ;;
    esac

    [[ "$cur" == --port=* ]] && { COMPREPLY=(); return; }

    if [[ "$already" =~ --serve ]]; then
        mapfile -t COMPREPLY < <(compgen -W "--port= -d --dir -h --help" -- "$cur")
        [[ "${COMPREPLY[0]}" == --port= ]] && compopt -o nospace 2>/dev/null
        return
    fi

    mapfile -t COMPREPLY < <(compgen -W "--serve --time --manual --wrap --dir --freq --port= --help -t -m -w -d -f -h" -- "$cur")
    [[ "${COMPREPLY[0]}" == --port= ]] && compopt -o nospace 2>/dev/null
}
complete -F _perf_use perf_use.bash ./perf_use.bash
