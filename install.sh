#!/usr/bin/env bash
# install.sh — install ghfzf + shell wrapper(s) for bash/zsh.
#
# What it does (idempotently):
#   1. Verifies dependencies: gh, git, fzf, jq.
#   2. Installs ghfzf into ~/.local/bin (symlink by default, or --copy).
#   3. Installs ghj.sh into ~/.config/ghj/ (symlink by default, or --copy).
#   4. Adds a "source ~/.config/ghj/ghj.sh" line to ~/.bashrc and/or ~/.zshrc
#      unless already present.

set -euo pipefail

die() { printf 'install.sh: ERROR %s\n' "$*" >&2; exit 1; }
warn() { printf 'install.sh: WARN %s\n' "$*" >&2; }
info() { printf 'install.sh: %s\n' "$*" >&2; }

mode="link"
do_bash=0
do_zsh=0

usage() {
  cat <<'EOF'
Usage:
  ./install.sh --bash        # install + enable for bash (~/.bashrc)
  ./install.sh --zsh         # install + enable for zsh  (~/.zshrc)
  ./install.sh --bash --zsh  # enable both
  ./install.sh --copy ...    # copy files instead of symlinks
  ./install.sh --help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --copy) mode="copy" ;;
    --bash) do_bash=1 ;;
    --zsh)  do_zsh=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
  shift
done

if [ "$do_bash" -eq 0 ] && [ "$do_zsh" -eq 0 ]; then
  die "pick at least one shell: --bash and/or --zsh"
fi

for dep in gh git fzf jq; do
  command -v "$dep" >/dev/null 2>&1 || die "missing dependency: $dep"
done
info "dependencies OK (gh, git, fzf, jq)"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src_bin="$script_dir/ghfzf"
src_wrap="$script_dir/ghj.sh"

[ -f "$src_bin" ] || die "source not found: $src_bin"
[ -f "$src_wrap" ] || die "source not found: $src_wrap"
chmod +x "$src_bin" "$src_wrap"

bin_dir="$HOME/.local/bin"
cfg_dir="$HOME/.config/ghj"
dst_bin="$bin_dir/ghfzf"
dst_wrap="$cfg_dir/ghj.sh"

mkdir -p "$bin_dir" "$cfg_dir"

rm -f "$dst_bin" "$dst_wrap"
case "$mode" in
  link)
    ln -s "$src_bin" "$dst_bin"
    ln -s "$src_wrap" "$dst_wrap"
    info "linked $dst_bin -> $src_bin"
    info "linked $dst_wrap -> $src_wrap"
    ;;
  copy)
    cp "$src_bin" "$dst_bin"
    cp "$src_wrap" "$dst_wrap"
    chmod +x "$dst_bin" "$dst_wrap"
    info "copied $src_bin to $dst_bin"
    info "copied $src_wrap to $dst_wrap"
    ;;
  *)
    die "unknown mode: $mode"
    ;;
esac

ensure_source_line() {
  local rcfile="$1"
  local line='[ -f "$HOME/.config/ghj/ghj.sh" ] && source "$HOME/.config/ghj/ghj.sh"'
  if [ ! -f "$rcfile" ]; then
    touch "$rcfile"
  fi
  if grep -Fqs "$line" "$rcfile"; then
    info "$rcfile already sources ghj"
  else
    printf '\n# ghfzf/ghj\n%s\n' "$line" >> "$rcfile"
    info "updated $rcfile to source ghj"
  fi
}

if [ "$do_bash" -eq 1 ]; then
  ensure_source_line "$HOME/.bashrc"
fi
if [ "$do_zsh" -eq 1 ]; then
  ensure_source_line "$HOME/.zshrc"
fi

cat >&2 <<EOF

✓ installed.
  • binary:   $dst_bin
  • wrapper:  $dst_wrap

Open a new shell (or re-source your rc file), then run:
  ghj fetch
  ghj
EOF
