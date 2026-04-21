function ghj --description 'Fuzzy-pick a GitHub repo with ghfzf and cd into it (clones on first use).'
    # ghfzf prints the absolute checkout path to stdout; progress/errors go
    # to stderr so they pass through to the terminal untouched.
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
