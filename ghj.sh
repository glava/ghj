#!/usr/bin/env bash
# ghj.sh — bash/zsh function wrapper for ghfzf.
#
# Source this file from your shell rc to get:
#   - `ghj`       : fuzzy-pick a repo and cd into it
#   - `ghj fetch` : update the local repo cache (no picker)
#
# NOTE: This must be a shell function (not a standalone binary) because a child
# process cannot change the parent shell's working directory.

ghj() {
    local subcmd="${1:-}"
    if [ "$subcmd" = "fetch" ]; then
        shift
        command ghfzf --fetch "$@"
        return $?
    fi

    local path
    path=$(command ghfzf --print-path "$@") || return $?
    [ -n "$path" ] || return 0
    cd -- "$path"
}
