# ghfzf

> Fuzzy-pick any GitHub repo you have access to, and `cd` straight into it.
> Clones it on first use into `~/<owner>/<repo>`.

`ghfzf` is a ~220-line bash script that pipes the list of every repo you can
see on GitHub (owner, collaborator, org member — all of them) into
[`fzf`](https://github.com/junegunn/fzf), with a colored picker and a live
preview pane. Its companion fish function `ghj` takes whichever repo you
select and — if it's not already on disk — clones it via SSH into a
predictable layout, then drops you inside the folder.

The net effect: stop thinking about "is this repo on my machine yet?" Just
type `ghj`, fuzzy-search, enter.

![screenshot placeholder — run `ghj` to see it live](#)

## Highlights

- **Works across every repo you can see.** Single paginated GraphQL call
  through `gh api`; ~1 second for a cached list, ~30-60s for the first
  fetch against a large-org account (1200+ repos tested).
- **Predictable checkout layout.** `~/<owner>/<repo>` by default
  (e.g. `~/acme/api`, `~/alice/dotfiles`). Override with `$GHFZF_ROOT`.
- **SSH clones** — uses `git@github.com:<owner>/<repo>.git` directly, never
  falls back to HTTPS.
- **Smart ranking.** Repo-name matches rank above description matches (the
  basename is the first matchable column in `fzf`); fuzzy matching is left
  on, so typos like `knits` still find `kubernetes`.
- **Color-coded.** Repo name in bold cyan, owner in soft gray, language
  tinted per-language (GitHub-ish palette), archived repos dimmed so they
  recede. Respects `NO_COLOR`.
- **Cached.** Uses a local cache; never refreshes it implicitly. Run
  `ghj fetch` (or `ghfzf --fetch`) when you want to update it.
- **Fish-first.** Installer is `install.fish`; `ghj` is a native fish
  autoloaded function. (The core `ghfzf` tool works from any shell; it's
  just the `cd`-the-parent-shell part that's fish-specific.)

## Requirements

- [`gh`](https://cli.github.com/) — authenticated (`gh auth login -s repo,read:org -p ssh`)
- `git`
- [`fzf`](https://github.com/junegunn/fzf)
- `jq`
- `fish` — for the `ghj` wrapper and the installer
- macOS or Linux

On macOS:

```bash
brew install gh fzf jq fish
gh auth login -s repo,read:org -p ssh
```

## Install

### fish

```fish
./install.fish
```

What the installer does, all idempotently:

1. Verifies the four deps above are on `PATH`.
2. Symlinks `./ghfzf` into `~/.local/bin/ghfzf` and adds `~/.local/bin` to
   `fish_user_paths` via `fish_add_path`.
3. Symlinks `./ghj.fish` into `~/.config/fish/functions/` so fish autoloads
   the `ghj` function.
4. Warns if `gh auth status` isn't green.

Symlinks (the default) mean you can edit `ghfzf` / `ghj.fish` in this repo
and changes take effect immediately, no reinstall. Pass `./install.fish
--copy` to install plain copies instead.

Open a new fish shell (or `exec fish`) and you're ready.

### bash / zsh

```bash
./install.sh --bash   # or: --zsh, or both
```

## Use

### The everyday flow

```fish
ghj fetch            # fetch/update the repo cache (run whenever you need it)
ghj                  # fuzzy-pick -> cd into the checkout (clones if missing)
```

### All `ghfzf` options

```
ghfzf                   # pick -> ensure checkout -> print absolute path (default)
ghfzf --print-path      # same as default, explicit
ghfzf --print           # pick -> print "owner/repo", no clone
ghfzf --open            # pick -> open in browser
ghfzf --clone           # pick -> clone into ~/<owner>/<repo> (and print)
ghfzf --ensure owner/r  # non-interactive: ensure checkout, print path
ghfzf --fetch           # fetch & write repo cache, then exit
ghfzf -r                # force-refresh the repo cache (alias: --refresh)
ghfzf --list            # print the cached repo list (plain "owner/repo" per line)
ghfzf --help
```

`ghfzf` always prints the result to stdout; progress and diagnostics go to
stderr, so it composes cleanly with other commands.

### In the picker

- `Enter` — ensure checkout and print the path (what `ghj` consumes).
- `Ctrl-O` — open the selected repo in your browser via `gh browse`.
- `Ctrl-Y` — copy the repo URL to the clipboard (macOS `pbcopy`).
- `Ctrl-R` — force-refresh the repo cache in place.
- Prefix a search term with `'` for an exact-match-only term
  (fzf's built-in). Otherwise fuzzy matching is on by default.

## Layout

```
~/
├── acme/                # org you belong to
│   ├── api/
│   ├── payments/
│   └── ...
├── alice/               # your personal account
│   ├── dotfiles/
│   └── ...
└── other-org/
    └── ...
```

Set `GHFZF_ROOT=/path/to/src` to put checkouts under that directory instead
of `$HOME`. The `<owner>/<repo>` structure still applies:
`$GHFZF_ROOT/<owner>/<repo>`.

## Environment variables

| Var           | Default            | Purpose                                                   |
| ------------- | ------------------ | --------------------------------------------------------- |
| `GHFZF_ROOT`  | `$HOME`            | Parent dir for checkouts; final path is `$ROOT/<owner>/<repo>` |
| `NO_COLOR`    | unset              | Disable all ANSI coloring (follows <https://no-color.org>) |
| `XDG_CACHE_HOME` | `$HOME/.cache`  | Where the repo cache is stored (`$XDG_CACHE_HOME/ghfzf/`) |

## How the fzf picker is put together

A few implementation details worth knowing if you want to tweak it:

- **Columns are emitted by `jq` as TSV**, padded to fixed widths, then
  wrapped in ANSI color sequences. Padding happens *before* coloring so
  column widths are based on visible character length, not byte length.
- **Hidden columns** at the end of each row carry: the full JSON blob for
  the selected repo (fed to the preview pane) and a plain ANSI-free
  `owner/repo` (used by action dispatch, clipboard, and `--list`).
- **Basename first for ranking.** The first visible column is the bare repo
  basename (e.g. `api`, not `acme/api`). fzf's scorer heavily rewards
  matches that start at position 0 of a matchable field, so queries against
  the short name reliably outrank description-only matches. Fuzzy matching
  is still on, so transposition typos work.
- **Sticky header** via `fzf --header-lines=1`: the first emitted line is
  `REPO / OWNER / LANG / DESCRIPTION` with the same padding as the data
  rows, wrapped in bold+underlined.
- **`Ctrl-R` reload** delegates back into the script (`ghfzf --refresh
  --rows`) rather than inlining jq in a bind spec, to sidestep fzf's
  comma-splitting of bind action lists.

## Why fish-only for the wrapper

A child process can't change its parent shell's working directory, so
`ghj` has to be a **function in your shell**, not a separate binary. I use
fish, so `ghj.fish` is what's in the repo. For bash/zsh, this repo ships
`ghj.sh` (and `install.sh` wires it into your rc file).

## Files in this repo

| File            | What                                                                       |
| --------------- | -------------------------------------------------------------------------- |
| `ghfzf`         | The main script: fetches, caches, picks, clones, prints paths              |
| `ghj.fish`      | Fish function that runs `cd "$(ghfzf --print-path $argv)"`                 |
| `ghj.sh`        | bash/zsh function wrapper (source it from your rc file)                    |
| `install.fish`  | One-shot installer (dep check, symlinks, `fish_user_paths`)                |
| `install.sh`    | One-shot installer for bash/zsh                                            |
| `README.md`     | This file                                                                  |

## Troubleshooting

**"I'm getting stale results."**
Run `ghj fetch` (or `ghfzf --fetch`). You can also press `Ctrl-R` in the picker.

**"Repository not found" on clone.**
Three usual causes:
1. Your `gh` token scopes are too narrow — re-run `gh auth login -s repo,read:org`.
2. Your SSH key isn't registered with GitHub — `gh ssh-key list` should show it.
3. You actually can't see the repo (it was deleted, or you were removed
   from the org since the last cache refresh).

**"The picker is slow on the first run."**
Expected. The initial `ghj fetch` / `ghfzf --fetch` makes one paginated GraphQL
request to fetch every repo you can see. For accounts with 1000+ repos that's
20-60s. All subsequent picks use the local cache and open instantly.

**"I want plain output for piping."**
`NO_COLOR=1 ghfzf --list` — one `owner/repo` per line, no ANSI.

## License

MIT.
