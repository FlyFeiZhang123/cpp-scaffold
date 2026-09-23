# bash completion for task_tracker.bash
#
# 和这个目录里其他补全不一样：task_tracker.bash 是「每个项目一份」，
# 而且补全要列当前项目自己的任务 ID —— 在这里写死没有意义。
# 做法是 Tab 时从 $PWD 往上找到本项目的那个脚本，让它自己吐补全（--completion）。
#
# 重载判据是「绝对路径 + 修改时间 + 大小」，不是只有路径：
#   - 换项目     → 路径变了 → 必须重载，否则补出来的是上一个项目的 ID；
#   - 原地改脚本 → 路径没变，但 mtime / 大小变了 → 同样要重载。
# 早先只有路径判据，结果改完脚本得重开终端才生效，白折腾半天。
_tt_stamp=""            # 上次加载的：绝对路径|mtime|大小

_task_tracker_complete_shim() {
    local d="$PWD" s="" r st
    while :; do
        [[ -f "$d/task_tracker.bash" ]] && { s="$d/task_tracker.bash"; break; }
        [[ "$d" == "/" ]] && break
        d="${d%/*}"; [[ -n "$d" ]] || d="/"
    done

    # 不在任何项目里 —— 别去调上一个项目残留的函数，那会补出错的 ID
    [[ -n "$s" ]] || { COMPREPLY=(); return 0; }

    r="$(realpath -- "$s" 2>/dev/null)" || r="$s"
    st="$(stat -c '%Y-%s' -- "$r" 2>/dev/null)" || st="?"
    if [[ "$r|$st" != "$_tt_stamp" ]]; then
        # --completion 的输出里带一行 `complete -F` 注册，会把 shim 自己的注册顶掉，
        # 所以 source 完要再注册一次，把控制权抢回来。
        # 用 bash 显式调用，免得脚本没有可执行位就整个失效。
        # shellcheck source=/dev/null  # 源是 <(...) 进程替换，内容运行时才生成，静态跟不了
        if source <(bash "$r" --completion 2>/dev/null); then
            _tt_stamp="$r|$st"
            complete -F _task_tracker_complete_shim task_tracker.bash ./task_tracker.bash
        else
            COMPREPLY=(); return 0
        fi
    fi

    _task_tracker_complete
    return 0
}

complete -F _task_tracker_complete_shim task_tracker.bash ./task_tracker.bash
