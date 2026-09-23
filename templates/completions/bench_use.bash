# bash completion for bench_use.bash
#
# 用 mapfile 而不是 COMPREPLY=($(compgen ...))：后者按空白切分，文件名里带空格会被
# 切成两条；mapfile 按行读，原样保留。
_bench_use() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    local cword="${COMP_CWORD}"

    case "$prev" in
        --out)
            [ -d "out/bench" ] && mapfile -t COMPREPLY < <(cd out/bench && compgen -f -- "$cur" | grep '\.json$')
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
        # 不能写成 mapfile <<< "$files"：空串也会喂进一个空元素，等于给出一条空候选。
        # 先置空数组，非空才填。
        COMPREPLY=()
        [ -n "$files" ] && mapfile -t COMPREPLY <<< "$files"
        return
    fi

    mapfile -t COMPREPLY < <(compgen -W "--json --compare --list --out --bind --filter --repeat --help" -- "$cur")
}
complete -F _bench_use bench_use.bash ./bench_use.bash
