# bash completion for my_build.bash
_my_build() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    local line="${COMP_LINE:0:COMP_POINT}"
    local already="${COMP_WORDS[*]}"

    # ── 所有选项（提前定义，唯一性检查需要）──
    local opts="--exe-src --which -w -j test lto valgrind ubsan"
    [[ ! "$already" =~ asan && ! "$already" =~ no-asan ]] && opts+=" asan no-asan"
    [[ ! "$already" =~ asan && ! "$already" =~ tsan ]]   && opts+=" tsan"
    [[ ! "$already" =~ perf && ! "$already" =~ no-perf ]] && opts+=" perf no-perf"
    [[ ! "$already" =~ march && ! "$already" =~ no-march ]] && opts+=" march no-march"
    [[ ! "$already" =~ release && ! "$already" =~ debug ]] && opts+=" release debug"

    # ── 唯一前缀智能补全 ──
    # $cur 是 --exe-src 的唯一前缀时，自动补 = 无空格
    if [[ "--exe-src" == "$cur"* && "$cur" != *=* ]]; then
        local unique=1
        for opt in $opts --exe-src; do
            [[ "$opt" == "--exe-src" ]] && continue
            [[ "$opt" == "$cur"* ]] && { unique=0; break; }
        done
        if (( unique )); then
            COMPREPLY=("--exe-src=")
            compopt -o nospace 2>/dev/null
            return
        fi
    fi

    # ── --exe-src=xxx 文件补全（用原始命令行，绕过 = 切分）──
    case "$line" in
        *--exe-src=*)
            local prefix="${line##*--exe-src=}"
            if [ -d example ]; then
                COMPREPLY=($(cd example && compgen -f -- "$prefix" | grep '\.cpp$'))
            fi
            return
            ;;
    esac

    # ── --exe-src xxx（= 被 bash 消耗，prev 变 --exe-src）──
    if [[ "$prev" == "--exe-src" ]]; then
        [ -d example ] && COMPREPLY=($(cd example && compgen -f -- "$cur" | grep '\.cpp$'))
        return
    fi

    # ── -jN 不补全 ──
    [[ "$cur" == -j* ]] && { COMPREPLY=(); return; }

    # ── 选项补全 ──
    COMPREPLY=($(compgen -W "$opts" -- "$cur"))
}
complete -F _my_build my_build.bash ./my_build.bash
