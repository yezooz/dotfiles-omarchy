#!/usr/bin/env bash
#
# dotfiles-omarchy installer.
#
# Layers personal config on top of Omarchy. Everything it does is a symlink,
# a guarded one-line append to ~/.bashrc, or an `omarchy pkg add` call — so a
# second run is a no-op and nothing here fights `omarchy update`.
#
#   ./install.sh              link everything, install the post-update hook
#   ./install.sh --check      dry run; print what would happen, change nothing
#   ./install.sh --links-only links only (what the post-update hook runs)
#   ./install.sh --packages   also install packages.txt via `omarchy pkg add`

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="$(hostname)"

DRY_RUN=false
DO_HOOK=true
DO_PACKAGES=false

for arg in "$@"; do
  case "$arg" in
    --check)      DRY_RUN=true ;;
    --links-only) DO_HOOK=false ;;
    --packages)   DO_PACKAGES=true ;;
    -h|--help)    sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

changed=0

info()  { printf '  %s\n' "$*"; }
act()   { printf '\033[32m  + %s\033[0m\n' "$*"; changed=$((changed + 1)); }
warn()  { printf '\033[33m  ! %s\033[0m\n' "$*"; }
header(){ printf '\n\033[1m%s\033[0m\n' "$*"; }

# link <source-relative-to-repo> <absolute-target>
#
# No-op when the correct symlink already exists. A real file or a symlink
# pointing elsewhere is moved aside to <target>.bak.<epoch> before relinking,
# so nothing is ever destroyed silently.
link() {
  local src="$DOTFILES/$1" dest="$2"

  if [[ ! -e $src ]]; then
    warn "missing in repo, skipped: $1"
    return 0
  fi

  if [[ -L $dest && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
    return 0    # already correct
  fi

  if $DRY_RUN; then
    if [[ -e $dest || -L $dest ]]; then
      act "would back up and relink $dest -> $1"
    else
      act "would link $dest -> $1"
    fi
    return 0
  fi

  mkdir -p "$(dirname "$dest")"

  if [[ -e $dest || -L $dest ]]; then
    local backup="$dest.bak.$(date +%s)"
    mv "$dest" "$backup" || { warn "could not back up $dest"; return 1; }
    info "backed up $dest -> $backup"
  fi

  ln -s "$src" "$dest" && act "linked $dest -> $1"
}

# Append a guarded source line to ~/.bashrc, once.
#
# ~/.bashrc stays Omarchy's own file; we only add the hand-off. Omarchy's rc
# runs first, so everything in shell/rc layers on top of its defaults.
ensure_bashrc() {
  local rc="$HOME/.bashrc"
  local marker='.dotfiles-omarchy/shell/rc'
  local line='[ -r "$HOME/.dotfiles-omarchy/shell/rc" ] && . "$HOME/.dotfiles-omarchy/shell/rc"'

  if [[ -f $rc ]] && grep -qF "$marker" "$rc"; then
    return 0
  fi

  if $DRY_RUN; then
    act "would append the dotfiles-omarchy source line to $rc"
    return 0
  fi

  printf '\n# dotfiles-omarchy\n%s\n' "$line" >> "$rc" &&
    act "appended source line to $rc"
}

# The installed hook is a stub that execs the repo copy, so the real logic
# stays version controlled. `omarchy hook install` copies its argument in,
# which is exactly why the copied file must stay trivial.
install_hook() {
  local dir="$HOME/.config/omarchy/hooks/post-update.d"
  local dest="$dir/10-dotfiles"
  local src="$DOTFILES/hooks/post-update.d/10-dotfiles"

  if [[ -f $dest ]] && cmp -s "$src" "$dest"; then
    return 0
  fi

  if $DRY_RUN; then
    act "would install post-update hook at $dest"
    return 0
  fi

  if command -v omarchy >/dev/null 2>&1; then
    omarchy hook install post-update "$src" >/dev/null 2>&1 && act "installed post-update hook" && return 0
  fi

  mkdir -p "$dir" && install -m 755 "$src" "$dest" && act "installed post-update hook at $dest"
}

install_packages() {
  local list="$DOTFILES/packages.txt"
  [[ -f $list ]] || { warn "no packages.txt"; return 0; }

  if ! command -v omarchy >/dev/null 2>&1; then
    warn "omarchy not on PATH; skipping packages"
    return 0
  fi

  local -a repo=() aur=()
  local line pkg
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"      # trim
    [[ -z $line ]] && continue
    if [[ $line == aur:* ]]; then
      pkg="${line#aur:}"
      pacman -Q "$pkg" >/dev/null 2>&1 || aur+=("$pkg")
    else
      pacman -Q "$line" >/dev/null 2>&1 || repo+=("$line")
    fi
  done < "$list"

  if ((${#repo[@]} == 0 && ${#aur[@]} == 0)); then
    info "all packages already installed"
    return 0
  fi

  if $DRY_RUN; then
    ((${#repo[@]})) && act "would run: omarchy pkg add ${repo[*]}"
    ((${#aur[@]}))  && act "would run: omarchy pkg aur add ${aur[*]}"
    return 0
  fi

  ((${#repo[@]})) && { act "omarchy pkg add ${repo[*]}"; omarchy pkg add "${repo[@]}"; }
  ((${#aur[@]}))  && { act "omarchy pkg aur add ${aur[*]}"; omarchy pkg aur add "${aur[@]}"; }
  return 0
}

$DRY_RUN && printf '\033[1mDry run — nothing will be changed.\033[0m\n'

header "Shell"
ensure_bashrc

header "Git and tools"
link config/git/config "$HOME/.gitconfig"
link config/git/ignore "$HOME/.config/git/ignore"
link config/psqlrc    "$HOME/.psqlrc"

# Only the four files we own. hyprland.lua, .luarc.json, hyprsunset.conf and
# xdph.conf stay Omarchy's, so `omarchy refresh hyprland` keeps working.
header "Hyprland"
for f in bindings input looknfeel autostart; do
  link "config/hypr/$f.lua" "$HOME/.config/hypr/$f.lua"
done
if [[ -f "$DOTFILES/hosts/$HOST/hypr/monitors.lua" ]]; then
  link "hosts/$HOST/hypr/monitors.lua" "$HOME/.config/hypr/monitors.lua"
else
  info "no monitors.lua for host '$HOST'; leaving Omarchy's in place"
fi

header "Omarchy desktop"
link config/omarchy/shell.json "$HOME/.config/omarchy/shell.json"
link config/omarchy/extensions/omarchy-menu.jsonc \
     "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"

# ~/.local/bin is already on PATH via Omarchy's env, so link scripts in
# individually rather than putting the repo's bin/ on PATH.
header "Scripts"
for script in "$DOTFILES"/bin/*; do
  [[ -f $script ]] || continue
  link "bin/$(basename "$script")" "$HOME/.local/bin/$(basename "$script")"
done

if $DO_HOOK; then
  header "Hooks"
  install_hook
fi

if $DO_PACKAGES; then
  header "Packages"
  install_packages
fi

header "Done"
if ((changed == 0)); then
  info "everything already in place"
elif $DRY_RUN; then
  info "$changed change(s) would be made — rerun without --check to apply"
else
  info "$changed change(s) made"
  info "open a new shell, or: source ~/.bashrc"
fi
