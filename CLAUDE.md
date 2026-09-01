# dotfiles-omarchy

Personal config layered on Omarchy (Arch + Hyprland + Quickshell). The guiding
rule: **carry only deltas, and never fight upstream.** Omarchy ships bash +
starship, eza/zoxide/fzf/bat/fd/rg, mise, tmux, LazyVim, lazygit, btop and a
themed git config. If Omarchy already provides something, it does not belong
here.

## Before adding anything

Check whether Omarchy already does it:

```bash
cat /usr/share/omarchy/default/bash/{aliases,envs,init,functions}
ls  /usr/share/omarchy/default/bash/fns/
cat /usr/share/omarchy/config/git/config
omarchy commands
```

`/usr/share/omarchy/` is read-only — reading it is encouraged, editing it is
not; `omarchy update` overwrites it.

## Layering rules

- **`shell/aliases` runs after Omarchy's**, so anything defined there shadows
  an Omarchy default. Add a name only after confirming it is free. Known
  collisions, all resolved in Omarchy's favour: `ga` (worktree add), `gd`
  (worktree remove), `c`, `d`, `t`, `a`, `r`, `h`, `n`, `cd`, `ls`, `lt`, `..`.
- **`g` is the one deliberate override.** A bash alias shadows a same-named
  function at parse time, hence the `unalias g` immediately above the
  definition in `shell/functions`.
- **`shell/inputrc` is applied last with `bind -f`.** Omarchy's rc ends with
  its own `bind -f`, so readline settings applied earlier are lost.
- **Git**: `~/.gitconfig` (this repo) beats `~/.config/git/config` (Omarchy).
  Never set something here that Omarchy already sets identically.
- **Hyprland**: link individual files. `hyprland.lua`, `.luarc.json`,
  `hyprsunset.conf` and `xdph.conf` belong to Omarchy.
- **Rebinding a Hyprland key** that Omarchy uses requires `hl.unbind(...)`
  first. Check with `omarchy menu keybindings --print`, and validate any change
  with `hyprctl reload && hyprctl configerrors`.
- **Window rules**: check the current Hyprland wiki. The syntax changes between
  versions; do not write it from memory.

## install.sh

Every operation is idempotent. `link()` no-ops on an already-correct symlink
and backs up anything real to `<path>.bak.<epoch>`. `ensure_bashrc()` greps
before appending. Adding a new managed file means one `link` call, nothing else.

Always test with `./install.sh --check` first.

## Deliberately not here

Neovim, tmux, starship, lazygit and btop configs (Omarchy's are good and stay
themed); fonts (`omarchy font set`); any vendored binary (mise handles tool
versions); anything macOS.
