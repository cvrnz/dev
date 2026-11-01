#!/usr/bin/env zsh
# Copy skills and configs from this repo onto the system (macOS and Linux).
# Anything already at a destination is moved to ~/.dev-backups/<timestamp>/ first, never deleted.
set -euo pipefail

SCRIPT_DIR=${0:A:h}
ENV_DIR=${SCRIPT_DIR:h}
REPO_DIR=${ENV_DIR:h}
# Configs shared by every environment live in common/, gibbon's own ones in env-gibbon/
COMMON_DIR=$REPO_DIR/common
CONFIGS_DIR=$ENV_DIR/configs
SKILLS_DIR=$ENV_DIR/skills
BACKUP_DIR=$HOME/.dev-backups/$(date +%Y%m%d-%H%M%S)
BACKED_UP=0

CLAUDE_SKILLS_DEST=${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills
STARSHIP_DEST=${STARSHIP_CONFIG:-$HOME/.config/starship.toml}
NVIM_DEST=${XDG_CONFIG_HOME:-$HOME/.config}/nvim
GHOSTTY_DEST=${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config
ZSHRC_DEST=${ZDOTDIR:-$HOME}/.zshrc
if [[ $OSTYPE == darwin* ]]; then
  VSCODE_DIR="$HOME/Library/Application Support/Code/User"
else
  VSCODE_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/Code/User
fi
# tmux reads ~/.tmux.conf first, so keep using it if it's already there
if [[ -e $HOME/.tmux.conf ]]; then
  TMUX_DEST=$HOME/.tmux.conf
else
  TMUX_DEST=${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf
fi

# Files that shouldn't be copied or compared
JUNK=(.DS_Store __pycache__ '*.pyc')

main() {
  build_items
  select_items

  local i any=0
  for i in {1..$#ITEMS}; do
    [[ ${SELECTED[i]} -eq 1 ]] || continue
    any=1
    if is_up_to_date "${ITEM_SRCS[i]}" "${ITEM_DESTS[i]}"; then
      log "${ITEM_LABELS[i]}: already up to date, skipping"
    else
      copy_item "${ITEM_LABELS[i]}" "${ITEM_SRCS[i]}" "${ITEM_DESTS[i]}"
    fi
  done
  [[ $any -eq 1 ]] || log "Nothing selected"

  [[ $BACKED_UP -eq 1 ]] && log "Previous versions saved in $BACKUP_DIR"
  log "Copy complete"
}

log() {
  echo "==> $*"
}

# Format: "group|label|source|destination"
ITEMS=()
ITEM_GROUPS=()
ITEM_LABELS=()
ITEM_SRCS=()
ITEM_DESTS=()
ITEM_STATES=()
SELECTED=()
CURSOR=1
MENU_LINES=0

build_items() {
  local d
  for d in $SKILLS_DIR/*(/N); do
    [[ -f $d/SKILL.md ]] && ITEMS+=("Skills|${d:t}|$d|$CLAUDE_SKILLS_DEST/${d:t}")
  done
  ITEMS+=(
    "Configs|Starship theme|$COMMON_DIR/starship.toml|$STARSHIP_DEST"
    "Configs|tmux config|$COMMON_DIR/tmux.conf|$TMUX_DEST"
    "Configs|Neovim config|$COMMON_DIR/nvim|$NVIM_DEST"
    "Configs|Ghostty config|$CONFIGS_DIR/ghostty.conf|$GHOSTTY_DEST"
    "Configs|zshrc|$CONFIGS_DIR/zshrc.sh|$ZSHRC_DEST"
    "Configs|VS Code settings|$CONFIGS_DIR/vscode-settings.jsonc|$VSCODE_DIR/settings.json"
    "Configs|VS Code keybindings|$CONFIGS_DIR/vscode-keybindings.jsonc|$VSCODE_DIR/keybindings.json"
  )
}

# A symlink never counts as up to date, so it gets replaced by a real copy
is_up_to_date() {
  local src=$1 dest=$2 x args=()
  [[ -e $dest && ! -L $dest ]] || return 1
  for x in $JUNK; do args+=(-x "$x"); done
  diff -rq $args "$src" "$dest" >/dev/null 2>&1
}

# Move whatever is at dest into the backup folder, keeping its path relative to $HOME
backup() {
  local dest=$1 rel target
  rel=${dest#$HOME/}
  [[ $rel == /* ]] && rel=${rel#/}
  target=$BACKUP_DIR/$rel
  mkdir -p "${target:h}"
  mv "$dest" "$target"
  BACKED_UP=1
  log "Moved old $dest to $target"
}

copy_item() {
  local label=$1 src=$2 dest=$3 x
  log "Copying $label"
  if [[ -e $dest || -L $dest ]]; then
    backup "$dest"
  fi
  mkdir -p "${dest:h}"
  cp -R "$src" "$dest"
  if [[ -d $dest ]]; then
    # Only touches the fresh copy, never the repo or the backup
    for x in $JUNK; do
      find "$dest" -name "$x" -prune -exec rm -rf {} +
    done
  fi
  log "$label copied to $dest"
}

# Colors
C_RESET=$'\e[0m'
C_BOLD=$'\e[1m'
C_DIM=$'\e[2m'
C_ACCENT=$'\e[38;2;137;180;250m'
C_GREEN=$'\e[38;2;166;218;149m'
C_HEADING=$'\e[38;2;223;142;29m'
C_SEL_BG=$'\e[48;5;236m'

menu_line() {
  printf '\e[2K%s\n' "$*"
  MENU_LINES=$((MENU_LINES + 1))
}

draw_menu() {
  local i group="" ptr box label state count=0 row_bg
  MENU_LINES=0
  for i in {1..$#ITEM_LABELS}; do
    if [[ ${ITEM_GROUPS[i]} != "$group" ]]; then
      group=${ITEM_GROUPS[i]}
      [[ $i -gt 1 ]] && menu_line ""
      menu_line "  ${C_HEADING}${C_BOLD}${(U)group}${C_RESET}"
    fi

    if [[ ${SELECTED[i]} -eq 1 ]]; then
      box="${C_GREEN}◉${C_RESET}"
      count=$((count + 1))
    else
      box="${C_DIM}○${C_RESET}"
    fi

    case ${ITEM_STATES[i]} in
      current) state="${C_DIM}${C_GREEN}✔ up to date${C_RESET}" ;;
      differs) state="${C_DIM}${C_HEADING}● differs, old copy will be backed up${C_RESET}" ;;
      *)       state="${C_DIM}new${C_RESET}" ;;
    esac

    if [[ $i -eq $CURSOR ]]; then
      ptr="${C_ACCENT}${C_BOLD}❯${C_RESET}"
      row_bg="${C_SEL_BG}${C_BOLD}${C_ACCENT}"
    else
      ptr=" "
      row_bg=""
    fi
    printf -v label '%s %-30s %s' "$box${row_bg}" "${ITEM_LABELS[i]}" "${C_RESET}"
    menu_line "  ${ptr} ${label}${state}"
  done

  menu_line ""
  menu_line "  ${C_DIM}${count} of ${#ITEM_LABELS} selected${C_RESET}"
  menu_line "  ${C_ACCENT}↑/↓${C_RESET}${C_DIM} move  ${C_RESET}${C_ACCENT}space${C_RESET}${C_DIM} toggle  ${C_RESET}${C_ACCENT}a${C_RESET}${C_DIM} all  ${C_RESET}${C_ACCENT}enter${C_RESET}${C_DIM} confirm  ${C_RESET}${C_ACCENT}q${C_RESET}${C_DIM} quit${C_RESET}"
}

select_items() {
  local i group label src dest key rest all n=$#ITEMS

  for i in {1..$n}; do
    IFS='|' read -r group label src dest <<<"${ITEMS[i]}"
    ITEM_GROUPS[i]=$group
    ITEM_LABELS[i]=$label
    ITEM_SRCS[i]=$src
    ITEM_DESTS[i]=$dest
    # Nothing starts selected, every item has to be picked by hand
    SELECTED[i]=0
    if is_up_to_date "$src" "$dest"; then
      ITEM_STATES[i]=current
    elif [[ -e $dest || -L $dest ]]; then
      ITEM_STATES[i]=differs
    else
      ITEM_STATES[i]=new
    fi
  done

  printf '\e[?25l'
  printf '\n  %s╭────────────────────────────────────────╮%s\n' "$C_ACCENT" "$C_RESET"
  printf '  %s│%s  %sCopy Dev Configs%s                      %s│%s\n' "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET" "$C_ACCENT" "$C_RESET"
  printf '  %s│%s  %sChoose what to copy to this system%s    %s│%s\n' "$C_ACCENT" "$C_RESET" "$C_DIM" "$C_RESET" "$C_ACCENT" "$C_RESET"
  printf '  %s╰────────────────────────────────────────╯%s\n\n' "$C_ACCENT" "$C_RESET"
  draw_menu

  while true; do
    IFS= read -rs -k 1 key </dev/tty
    if [[ $key == $'\e' ]]; then
      IFS= read -rs -k 2 -t 0.05 rest </dev/tty || rest=""
      key+=$rest
    fi
    case $key in
      $'\e[A'|k) CURSOR=$(( (CURSOR - 2 + n) % n + 1 )) ;;
      $'\e[B'|j) CURSOR=$(( CURSOR % n + 1 )) ;;
      ' ') SELECTED[CURSOR]=$(( 1 - SELECTED[CURSOR] )) ;;
      a)
        all=1
        for i in {1..$n}; do [[ ${SELECTED[i]} -eq 1 ]] || all=0; done
        for i in {1..$n}; do SELECTED[i]=$(( 1 - all )); done
        ;;
      $'\n'|$'\r') break ;;
      q) printf '\e[?25h'; log "Aborted"; exit 0 ;;
    esac
    printf '\e[%dA' "$MENU_LINES"
    draw_menu
  done

  # Replace the menu with a summary of what will be copied
  printf '\e[%dA\e[J' "$MENU_LINES"
  [[ ${SELECTED[(I)1]} -gt 0 ]] || { printf '\e[?25h'; return }
  printf '  %sCopying:%s\n' "$C_BOLD" "$C_RESET"
  for i in {1..$n}; do
    [[ ${SELECTED[i]} -eq 1 ]] && printf '    %s◉%s %s %s→ %s%s\n' "$C_GREEN" "$C_RESET" "${ITEM_LABELS[i]}" "$C_DIM" "${ITEM_DESTS[i]}" "$C_RESET"
  done
  printf '\n\e[?25h'
}

# Traps live at the top level: in zsh an EXIT trap set inside a function fires when that function returns
trap 'printf "\e[?25h"' EXIT
trap 'printf "\e[?25h\n"; exit 130' INT

main
