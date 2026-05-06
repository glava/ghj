#!/usr/bin/env fish
# install.fish — install ghfzf (the picker) and ghj (the fish wrapper).
#
# What it does:
#   1. Verifies dependencies: gh, git, fzf, jq.
#   2. Symlinks ghfzf into ~/.local/bin (creates the dir if needed) and makes
#      sure ~/.local/bin is on fish_user_paths.
#   3. Symlinks ghj.fish into ~/.config/fish/functions/ so it's autoloaded.
#   4. Reminds you to run `gh auth status` if you haven't authenticated yet.
#
# Symlinks (not copies) are used so editing ghfzf/ghj.fish in this repo takes
# effect immediately without reinstalling. Pass --copy to install actual copies
# instead. Safe to run multiple times.

set -l script_dir (status dirname)
set -l script_dir (realpath -- $script_dir)

set -l src_bin "$script_dir/ghfzf"
set -l src_fn  "$script_dir/ghj.fish"

set -l bin_dir "$HOME/.local/bin"
set -l fn_dir  "$HOME/.config/fish/functions"

set -l dst_bin "$bin_dir/ghfzf"
set -l dst_fn  "$fn_dir/ghj.fish"

set -l mode link
for arg in $argv
    switch $arg
        case --copy
            set mode copy
        case -h --help
            sed -n '2,14p' (status filename) | string replace -r '^# ?' ''
            exit 0
        case '*'
            echo "install.fish: unknown argument: $arg" >&2
            exit 2
    end
end

# ---------- helpers ----------

function __ghfzf_info
    set_color cyan; echo -n "install.fish: "; set_color normal
    echo $argv
end

function __ghfzf_warn
    set_color yellow; echo -n "install.fish: WARN "; set_color normal
    echo $argv
end

function __ghfzf_die
    set_color red; echo -n "install.fish: ERROR "; set_color normal
    echo $argv
    exit 1
end

# ---------- 1. dependency check ----------

set -l missing
for dep in gh git fzf jq
    if not command -q $dep
        set -a missing $dep
    end
end

if set -q missing[1]
    __ghfzf_warn "missing dependencies: $missing"
    echo "    install them with: brew install $missing"
    __ghfzf_die "aborting — install the missing tools and re-run this script."
end
__ghfzf_info "dependencies OK (gh, git, fzf, jq)"

# ---------- 2. install ghfzf into ~/.local/bin ----------

if not test -f "$src_bin"
    __ghfzf_die "source not found: $src_bin"
end
chmod +x "$src_bin"

mkdir -p "$bin_dir"

if test -L "$dst_bin" -o -e "$dst_bin"
    rm -f "$dst_bin"
end
switch $mode
    case link
        ln -s "$src_bin" "$dst_bin"
        __ghfzf_info "linked $dst_bin -> $src_bin"
    case copy
        cp "$src_bin" "$dst_bin"
        chmod +x "$dst_bin"
        __ghfzf_info "copied $src_bin to $dst_bin"
end

# fish_add_path is idempotent; it won't duplicate an existing entry and it
# persists across sessions via universal variables.
if not contains -- "$bin_dir" $fish_user_paths
    fish_add_path --path "$bin_dir"
    __ghfzf_info "added $bin_dir to fish_user_paths"
else
    __ghfzf_info "$bin_dir already on fish_user_paths"
end

# ---------- 3. install ghj fish function ----------

if not test -f "$src_fn"
    __ghfzf_die "source not found: $src_fn"
end

mkdir -p "$fn_dir"

if test -L "$dst_fn" -o -e "$dst_fn"
    rm -f "$dst_fn"
end
switch $mode
    case link
        ln -s "$src_fn" "$dst_fn"
        __ghfzf_info "linked $dst_fn -> $src_fn"
    case copy
        cp "$src_fn" "$dst_fn"
        __ghfzf_info "copied $src_fn to $dst_fn"
end

# ---------- 4. sanity checks ----------

if not gh auth status >/dev/null 2>&1
    __ghfzf_warn "`gh auth status` reports you're not logged in."
    echo "    run: gh auth login -s repo,read:org -p ssh"
end

echo
set_color green
echo "✓ installed."
set_color normal
echo "  • binary:   $dst_bin"
echo "  • function: $dst_fn"
echo
echo "Open a new fish shell (or run `exec fish`), then try:"
echo "    ghj                # fuzzy-pick a repo and jump into it"
echo "    ghj fetch          # fetch/update the repo cache"
echo "    ghfzf --help       # all ghfzf options"
