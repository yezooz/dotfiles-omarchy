# dotfiles-omarchy

Personal configuration layered on top of [Omarchy](https://omarchy.org/).

Omarchy already ships an opinionated stack — bash + starship, eza/zoxide/fzf/
bat/fd/rg, mise, tmux, LazyVim, lazygit, btop, and a themed git config. This
repo carries only the deltas, and is built so that nothing in it fights an
`omarchy update`.

The macOS half of my setup lives in [yezooz/dotfiles](https://github.com/yezooz/dotfiles).

## Install

```bash
git clone https://github.com/yezooz/dotfiles-omarchy.git ~/.dotfiles-omarchy
cd ~/.dotfiles-omarchy
./install.sh --check      # dry run: prints every action, changes nothing
./install.sh
```

Then open a new shell.

| Flag | Effect |
|---|---|
| *(none)* | Link everything and install the post-update hook |
| `--check` | Dry run |
| `--links-only` | Links only — what the post-update hook runs |
| `--packages` | Also install `packages.txt` via `omarchy pkg add` |

Re-running is safe: a link already pointing at the right place is left alone,
and anything real that would be overwritten is moved to `<path>.bak.<epoch>`
first.

## What it manages

| Repo path | Installed to |
|---|---|
| `shell/rc` | sourced from `~/.bashrc` (one appended line) |
| `config/git/config` | `~/.gitconfig` |
| `config/git/ignore` | `~/.config/git/ignore` |
| `config/psqlrc` | `~/.psqlrc` |
| `config/hypr/*.lua` | `~/.config/hypr/` (four files only) |
| `hosts/$(hostname)/hypr/monitors.lua` | `~/.config/hypr/monitors.lua` |
| `config/omarchy/shell.json` | `~/.config/omarchy/shell.json` |
| `config/omarchy/extensions/` | `~/.config/omarchy/extensions/` |
| `bin/*` | `~/.local/bin/` |
| `hooks/post-update.d/10-dotfiles` | `~/.config/omarchy/hooks/post-update.d/` |

## How it stays out of Omarchy's way

**`~/.bashrc` is never replaced.** `install.sh` appends one guarded `source`
line to Omarchy's own file. Since Omarchy's rc runs first, everything in
`shell/` layers on top of its defaults — which is also why `shell/aliases` is
kept short. Every alias added there silently shadows an Omarchy default.

**Git layers rather than overrides.** Git reads `~/.config/git/config`
(Omarchy's, which it themes and can refresh) and *then* `~/.gitconfig`, which
wins. Linking the latter means no include-injection and nothing to repair after
`omarchy refresh`.

**Hyprland is linked file by file, never as a directory.** `~/.config/hypr/`
also holds `hyprland.lua`, `.luarc.json`, `hyprsunset.conf` and `xdph.conf`,
which stay Omarchy's, so `omarchy refresh hyprland` keeps working.

**Scripts go to `~/.local/bin`,** already on `PATH` via Omarchy's env. Nothing
here manipulates `PATH`.

**A `post-update` hook re-runs `install.sh --links-only`,** so links survive
`omarchy update` and any `omarchy refresh` that replaces a managed file with a
stock one. The installed hook is a stub that execs the copy in this repo, so
the real logic stays version controlled.

## Alias collisions worth knowing

Omarchy binds several short names, some with meanings that differ from the
usual conventions. This repo leaves them alone:

| Key | On Omarchy |
|---|---|
| `ga` | `git worktree add` — **not** `git add`. Use `g add`. |
| `gd` | `git worktree remove` |
| `c` | `opencode --auto` |
| `d` | `docker` |
| `t` | tmux attach-or-create |

The one deliberate override is `g`, replaced with a function so that a bare
`g` runs `git status` and `g <args>` passes through to git.

## Machine-local settings

`~/.bashrc.local` is sourced if present and is not tracked. Use it for work
AWS profiles and anything else that should not be public:

```bash
export AWS_VAULT_PROFILE=...
export AWS_VAULT_ADMIN_PROFILE=...
export AWS_VAULT_POWER_PROFILE=...
```

A second machine gets its own `hosts/<hostname>/hypr/monitors.lua`. Hosts
without one keep Omarchy's default, so nothing breaks.
