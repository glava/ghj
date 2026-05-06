function ghj --description 'Fuzzy-pick a GitHub repo with ghfzf and cd into it (clones on first use).'
    # Special case: `ghj fetch` updates the local repo cache (no picker).
    if test (count $argv) -ge 1; and test "$argv[1]" = fetch
        command ghfzf --fetch
        return $status
    end

    # All extra args are forwarded to ghfzf (see `ghfzf --help`). ghfzf prints
    # the absolute checkout path to stdout; progress/errors go to stderr so
    # they pass through to the terminal untouched.
    set -l path (command ghfzf --print-path $argv)
    set -l rc $status
    if test $rc -ne 0
        return $rc
    end
    # User aborted fzf (empty selection) -> stay put.
    if test -z "$path"
        return 0
    end
    cd -- $path
end
