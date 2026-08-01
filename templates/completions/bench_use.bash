# bash completion for bench_use.bash
_bench_use() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    local cword="${COMP_CWORD}"

    case "$prev" in
        --out)
            [ -d "out/bench" ] && COMPREPLY=($(cd out/bench && compgen -f -- "$cur" | grep '\.json$'))
            return
            ;;
        --bind|--repeat|--filter)
            COMPREPLY=()
            return
            ;;
    esac

    # --compare：补全两个 JSON 文件（$prev=--compare 是第一个，$prev 是文件时是第二个）
    if [[ "$prev" == "--compare" || "${COMP_WORDS[cword-2]}" == "--compare" ]]; then
        local files=""
        [ -d "out/bench" ] && files=$(cd out/bench && compgen -f -- "$cur" | grep '\.json$')
        [ -z "$files" ] && files=$(compgen -f -- "$cur" | grep '\.json$')
        COMPREPLY=($files)
        return
    fi

    COMPREPLY=($(compgen -W "--json --compare --list --out --bind --filter --repeat --help" -- "$cur"))
}
complete -F _bench_use bench_use.bash ./bench_use.bash
