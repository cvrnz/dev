#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# In the repo the shared configs are in common/ at the root; in the image they're copied next to the script
if [[ -d $SCRIPT_DIR/../../common ]]; then
  COMMON_DIR="$(cd "$SCRIPT_DIR/../../common" && pwd)"
else
  COMMON_DIR="$SCRIPT_DIR/common"
fi
ARCH=$(dpkg --print-architecture)

main() {
  load_existing_env
  select_items

  local i any=0
  for i in "${!ITEMS[@]}"; do
    [[ ${SELECTED[i]} -eq 1 ]] || continue
    any=1
    # Re-check right before running, since earlier steps may have changed the state
    if "${ITEM_CHECKS[i]}" >/dev/null 2>&1; then
      log "${ITEM_LABELS[i]}: already set up, skipping"
    else
      "${ITEM_FUNCS[i]}"
    fi
  done
  [[ $any -eq 1 ]] || log "Nothing selected"

  log "Setup complete"
  cd ~/workspace 2>/dev/null || cd ~
  exec zsh
}

log() {
  echo "==> $*";
}

# Format: "group|function|label|enabled by default (1/0)|installed check"
ITEMS=(
  "System|install_apt_packages|apt packages (zsh, tmux, lsof, ripgrep)|1|is_apt_packages_installed"
  "System|install_git|git (git-core PPA)|1|is_git_installed"
  "Shell|create_workspace_folder|Workspace folder|1|is_workspace_folder_setup"
  "Shell|set_aliases|Aliases|1|is_aliases_setup"
  "Shell|set_custom_zsh_prompt|Custom zsh prompt|1|is_custom_prompt_setup"
  "Shell|install_starship|Starship|1|is_starship_installed"
  "Shell|configure_starship|Starship toggle|1|is_starship_configured"
  "Tools|install_neovim|Neovim|1|is_neovim_installed"
  "Tools|configure_neovim|Neovim config|1|is_neovim_configured"
  "Tools|configure_tmux|tmux config|1|is_tmux_configured"
  "Tools|install_zellij|Zellij|0|is_zellij_installed"
  "Languages|install_gleam|Gleam (via asdf)|1|is_gleam_installed"
  "Languages|install_fnm|fnm|1|is_fnm_installed"
  "Languages|install_node|Node LTS|1|is_node_installed"
  "Languages|install_pnpm|pnpm|1|is_pnpm_installed"
  "CLI Tools|install_claude_code|Claude Code|1|is_claude_installed"
  "CLI Tools|install_gh|GitHub CLI (gh)|1|is_gh_installed"
)
ITEM_GROUPS=()
ITEM_FUNCS=()
ITEM_LABELS=()
ITEM_INSTALLED=()
ITEM_CHECKS=()
SELECTED=()

ALIASES=(
  'alias ll="ls -lahG"'
  'alias z="nvim ~/.zshrc"'
  'alias sz="source ~/.zshrc"'
  'alias tmux="tmux -u"'
  'alias n="nvim"'
)

# Append lines to ~/.zshrc unless the marker text is already present
append_to_zshrc() {
  local marker=$1
  shift
  grep -qF -- "$marker" ~/.zshrc 2>/dev/null && return 0
  printf '%s\n' "$@" >> ~/.zshrc
}
CURSOR=0
MENU_LINES=0

# Make previously installed tools visible to the checks and later steps
load_existing_env() {
  export ASDF_DATA_DIR="$HOME/.asdf"
  export PATH="$HOME/.local/bin:$HOME/go/bin:$ASDF_DATA_DIR/shims:$PATH"
  if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --shell bash)"
  fi
}

is_apt_packages_installed()       { command -v zsh && command -v tmux && command -v lsof && command -v rg; }
is_git_installed()                { command -v git && grep -rqs 'git-core' /etc/apt/sources.list.d/; }
is_workspace_folder_setup()       { [[ -d ~/workspace ]]; }
is_aliases_setup() {
  local a
  for a in "${ALIASES[@]}"; do grep -qxF -- "$a" ~/.zshrc || return 1; done
}
is_custom_prompt_setup()          { grep -qxF '# custom zsh prompt' ~/.zshrc; }
is_starship_installed()           { command -v starship && cmp -s "$COMMON_DIR/starship.toml" ~/.config/starship.toml; }
is_starship_configured()          { grep -qF 'toggle_starship() {' ~/.zshrc; }
is_neovim_installed()             { command -v nvim; }
is_neovim_configured()            { diff -rq "$COMMON_DIR/nvim" ~/.config/nvim; }
is_tmux_configured()              { cmp -s "$COMMON_DIR/tmux.conf" ~/.tmux.conf; }
is_zellij_installed()             { command -v zellij; }
is_gleam_installed()              { command -v gleam; }
is_fnm_installed()                { command -v fnm && grep -qxF '# fnm' ~/.zshrc; }
is_node_installed()               { command -v node; }
is_pnpm_installed()               { command -v pnpm; }
is_claude_installed()             { command -v claude; }
is_gh_installed()                 { command -v gh; }

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
  local i group="" ptr box label status count=0 row_bg
  MENU_LINES=0
  for i in "${!ITEM_LABELS[@]}"; do
    if [[ ${ITEM_GROUPS[i]} != "$group" ]]; then
      group=${ITEM_GROUPS[i]}
      [[ $i -gt 0 ]] && menu_line ""
      menu_line "  ${C_HEADING}${C_BOLD}${group^^}${C_RESET}"
    fi

    if [[ ${SELECTED[i]} -eq 1 ]]; then
      box="${C_GREEN}◉${C_RESET}"
      count=$((count + 1))
    else
      box="${C_DIM}○${C_RESET}"
    fi

    status=""
    [[ ${ITEM_INSTALLED[i]} -eq 1 ]] && status="${C_DIM}${C_GREEN}✔ installed${C_RESET}"

    if [[ $i -eq $CURSOR ]]; then
      ptr="${C_ACCENT}${C_BOLD}❯${C_RESET}"
      row_bg="${C_SEL_BG}${C_BOLD}${C_ACCENT}"
    else
      ptr=" "
      row_bg=""
    fi
    printf -v label '%s %-30s %s' "$box${row_bg}" "${ITEM_LABELS[i]}" "${C_RESET}"
    menu_line "  ${ptr} ${label}${status}"
  done

  menu_line ""
  menu_line "  ${C_DIM}${count} of ${#ITEM_LABELS[@]} selected${C_RESET}"
  menu_line "  ${C_ACCENT}↑/↓${C_RESET}${C_DIM} move  ${C_RESET}${C_ACCENT}space${C_RESET}${C_DIM} toggle  ${C_RESET}${C_ACCENT}a${C_RESET}${C_DIM} all  ${C_RESET}${C_ACCENT}enter${C_RESET}${C_DIM} confirm  ${C_RESET}${C_ACCENT}q${C_RESET}${C_DIM} quit${C_RESET}"
}

select_items() {
  local i group func label default check key rest all n=${#ITEMS[@]}

  printf '%s\n' "${C_DIM}Checking what's already installed...${C_RESET}"
  for i in "${!ITEMS[@]}"; do
    IFS='|' read -r group func label default check <<<"${ITEMS[i]}"
    ITEM_GROUPS[i]=$group
    ITEM_FUNCS[i]=$func
    ITEM_LABELS[i]=$label
    ITEM_CHECKS[i]=$check
    SELECTED[i]=$default
    if "$check" >/dev/null 2>&1; then ITEM_INSTALLED[i]=1; else ITEM_INSTALLED[i]=0; fi
  done
  printf '\e[1A\e[2K'

  trap 'printf "\e[?25h"' EXIT
  trap 'printf "\e[?25h\n"; exit 130' INT
  printf '\e[?25l'
  printf '\n  %s╭────────────────────────────────────────╮%s\n' "$C_ACCENT" "$C_RESET"
  printf '  %s│%s  %sDev Environment Setup%s                 %s│%s\n' "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET" "$C_ACCENT" "$C_RESET"
  printf '  %s│%s  %sChoose what to install%s                %s│%s\n' "$C_ACCENT" "$C_RESET" "$C_DIM" "$C_RESET" "$C_ACCENT" "$C_RESET"
  printf '  %s╰────────────────────────────────────────╯%s\n\n' "$C_ACCENT" "$C_RESET"
  draw_menu

  while true; do
    IFS= read -rsn1 key </dev/tty
    if [[ $key == $'\e' ]]; then
      IFS= read -rsn2 -t 0.05 rest </dev/tty || true
      key+=$rest
    fi
    case $key in
      $'\e[A'|k) CURSOR=$(( (CURSOR - 1 + n) % n )) ;;
      $'\e[B'|j) CURSOR=$(( (CURSOR + 1) % n )) ;;
      ' ') SELECTED[CURSOR]=$(( 1 - SELECTED[CURSOR] )) ;;
      a)
        all=1
        for i in "${!SELECTED[@]}"; do [[ ${SELECTED[i]} -eq 1 ]] || all=0; done
        for i in "${!SELECTED[@]}"; do SELECTED[i]=$(( 1 - all )); done
        ;;
      '') break ;;
      q) printf '\e[?25h'; log "Aborted"; exit 0 ;;
    esac
    printf '\e[%dA' "$MENU_LINES"
    draw_menu
  done

  # Replace the menu with a summary of what will be installed
  printf '\e[%dA\e[J' "$MENU_LINES"
  printf '  %sInstalling:%s\n' "$C_BOLD" "$C_RESET"
  for i in "${!ITEM_LABELS[@]}"; do
    [[ ${SELECTED[i]} -eq 1 ]] && printf '    %s◉%s %s\n' "$C_GREEN" "$C_RESET" "${ITEM_LABELS[i]}"
  done
  printf '\n\e[?25h'
}

install_apt_packages() {
  local missing=()
  command -v zsh  &>/dev/null || missing+=(zsh)
  command -v tmux &>/dev/null || missing+=(tmux)
  command -v lsof &>/dev/null || missing+=(lsof)
  command -v rg   &>/dev/null || missing+=(ripgrep)

  log "Updating package lists"
  apt-get update -y

  log "Installing apt packages: ${missing[*]}"
  apt-get install -y "${missing[@]}"
  log "apt packages installed"
}

install_git() {
  log "Installing latest git via git-core PPA"
  apt-get update -y
  apt-get install -y software-properties-common
  add-apt-repository -y ppa:git-core/ppa
  apt-get update -y
  apt-get install -y git
  log "git installed ($(git --version))"
}

create_workspace_folder() {
  log "Creating workspace folder"
  mkdir -p ~/workspace
  log "Workspace folder created"
}

set_aliases() {
  log "Setting aliases"
  local a
  for a in "${ALIASES[@]}"; do
    grep -qxF -- "$a" ~/.zshrc 2>/dev/null || echo "$a" >> ~/.zshrc
  done
  log "Aliases set"
}

set_custom_zsh_prompt() {
  log "Setting custom zsh prompt"
  append_to_zshrc '# custom zsh prompt' \
    '' \
    '# custom zsh prompt' \
    'setopt PROMPT_SUBST' \
    '_prompt_git_branch() {' \
    '  local branch' \
    '  branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return' \
    '  printf " %%{\033[38;2;223;142;29m%%}(%s)%%{\033[0m%%}" "${branch}"' \
    '}' \
    'PS1=$'"'"'%{\e[38;2;30;102;245m%}%~%{\e[0m%}$(_prompt_git_branch)\n> '"'"
  log "Custom zsh prompt set"
}

install_starship() {
  log "Installing Starship"
  if ! command -v starship &>/dev/null; then
    case "$(uname -m)" in
      x86_64)  STARSHIP_ARCH="x86_64" ;;
      aarch64) STARSHIP_ARCH="aarch64" ;;
      *)       echo "Unsupported architecture: $(uname -m)" && exit 1 ;;
    esac
    curl -fsSL "https://github.com/starship/starship/releases/latest/download/starship-${STARSHIP_ARCH}-unknown-linux-musl.tar.gz" \
      | tar xz -C /usr/local/bin
  fi
  if ! cmp -s "$COMMON_DIR/starship.toml" ~/.config/starship.toml; then
    mkdir -p ~/.config
    cp "$COMMON_DIR/starship.toml" ~/.config/starship.toml
  fi
  log "Starship installed"
}

configure_starship() {
  log "Configuring Starship"
  append_to_zshrc 'toggle_starship() {' \
    '' \
    '# Starship prompt (set USE_STARSHIP=false to disable)' \
    'USE_STARSHIP="${USE_STARSHIP:-true}"' \
    'if [ "$USE_STARSHIP" = "true" ]; then' \
    '  eval "$(starship init zsh)"' \
    'fi' \
    '' \
    'toggle_starship() {' \
    '  if [ "${USE_STARSHIP:-true}" = "true" ]; then' \
    '    export USE_STARSHIP=false' \
    '  else' \
    '    export USE_STARSHIP=true' \
    '  fi' \
    '  source ~/.zshrc' \
    '}' \
    'alias toggle-starship="toggle_starship"'
  log "Starship configured"
}

install_neovim() {
  log "Installing latest Neovim"
  case "$(uname -m)" in
    x86_64)  NVIM_ARCH="x86_64" ;;
    aarch64) NVIM_ARCH="arm64" ;;
    *)       echo "Unsupported architecture: $(uname -m)" && exit 1 ;;
  esac

  NVIM_VERSION=$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')

  curl -fsSL "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-${NVIM_ARCH}.tar.gz" \
    | tar xz -C /opt
  ln -sf "/opt/nvim-linux-${NVIM_ARCH}/bin/nvim" /usr/local/bin/nvim
  log "Neovim installed"
}

configure_neovim() {
  log "Copying Neovim config"
  if [[ -e ~/.config/nvim ]]; then
    local backup=~/.dev-backups/$(date +%Y%m%d-%H%M%S)/.config
    mkdir -p "$backup"
    mv ~/.config/nvim "$backup/nvim"
    log "Moved old ~/.config/nvim to $backup/nvim"
  fi
  mkdir -p ~/.config
  cp -R "$COMMON_DIR/nvim" ~/.config/nvim
  # Install the plugins now so the first launch doesn't have to
  nvim --headless +qa >/dev/null 2>&1 || true
  log "Neovim config copied"
}

configure_tmux() {
  log "Copying tmux config"
  if [[ -e ~/.tmux.conf ]]; then
    local backup=~/.dev-backups/$(date +%Y%m%d-%H%M%S)
    mkdir -p "$backup"
    mv ~/.tmux.conf "$backup/.tmux.conf"
    log "Moved old ~/.tmux.conf to $backup/.tmux.conf"
  fi
  cp "$COMMON_DIR/tmux.conf" ~/.tmux.conf
  log "tmux config copied"
}

install_zellij() {
  log "Installing Zellij"
  ZELLIJ_VERSION=$(curl -fsSL https://api.github.com/repos/zellij-org/zellij/releases/latest \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')

  case "$ARCH" in
    amd64)   ZELLIJ_ARCH="x86_64-unknown-linux-musl" ;;
    arm64)   ZELLIJ_ARCH="aarch64-unknown-linux-musl" ;;
    *)       echo "Unsupported architecture: $ARCH" && exit 1 ;;
  esac

  curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-${ZELLIJ_ARCH}.tar.gz" \
    | tar xz -C /tmp
  mv /tmp/zellij /usr/local/bin/zellij
  chmod +x /usr/local/bin/zellij
  log "Zellij installed"
}

install_gleam() {
  log "Installing Gleam dependencies"
  # asdf builds Erlang from source, so these dependencies are required
  apt-get update -y
  apt-get install -y \
    build-essential \
    autoconf \
    m4 \
    libncurses-dev \
    libssl-dev \
    libssh-dev

  log "Installing Go"
  apt-get install -y golang

  log "Installing asdf"
  go install github.com/asdf-vm/asdf/cmd/asdf@v0.19.0

  # asdf v0.16+ is a Go binary; shims must be on PATH instead of sourcing asdf.sh
  append_to_zshrc '# asdf' \
    '' \
    '# asdf' \
    'export ASDF_DATA_DIR="$HOME/.asdf"' \
    'export PATH="$HOME/go/bin:$ASDF_DATA_DIR/shims:$PATH"'

  log "Installing Gleam via asdf"
  asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
  asdf plugin add rebar https://github.com/Stratus3D/asdf-rebar.git
  asdf plugin add gleam https://github.com/vic/asdf-gleam.git

  asdf set -u erlang latest
  asdf set -u rebar latest
  asdf set -u gleam latest

  asdf install
  asdf reshim
  log "Gleam installed"
}

install_fnm() {
  log "Installing fnm"
  if ! command -v fnm &>/dev/null; then
    # --skip-shell: the ~/.zshrc block is added below instead
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir /usr/local/bin --skip-shell
  fi
  eval "$(fnm env --shell bash)"
  append_to_zshrc '# fnm' \
    '' \
    '# fnm' \
    'export PATH="$HOME/.local/bin:$PATH"' \
    'eval "$(fnm env --shell zsh)"'
  log "fnm installed"
}

install_node() {
  log "Installing latest Node.js via fnm"
  fnm install --lts
  log "Node.js installed"
}

install_pnpm() {
  log "Installing pnpm"
  npm i -g pnpm
  log "pnpm installed"
}

install_claude_code() {
  log "Installing Claude Code"
  npm install -g @anthropic-ai/claude-code
  log "Claude Code installed"
}

install_gh() {
  log "Installing latest GitHub CLI"
  case "$(uname -m)" in
    x86_64)  GH_ARCH="amd64" ;;
    aarch64) GH_ARCH="arm64" ;;
    *)       echo "Unsupported architecture: $(uname -m)" && exit 1 ;;
  esac

  GH_VERSION=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')

  curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz" \
    | tar xz -C /tmp
  mv "/tmp/gh_${GH_VERSION}_linux_${GH_ARCH}/bin/gh" /usr/local/bin/gh
  log "GitHub CLI installed"
}

main
