# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
	for rc in ~/.bashrc.d/*; do
		if [ -f "$rc" ]; then
			. "$rc"
		fi
	done
fi

unset rc
export PATH="$HOME/.local/bin:$PATH"
export PATH="/checode/checode-linux-libc/ubi9/bin/remote-cli:$PATH"
alias b="nvim ~/.bashrc"
alias sb="source ~/.bashrc"
alias c="clear"
alias ll="ls -lahG"
alias gp="cat /etc/hostname"

_prompt_git_branch() {
  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return
  printf " \001\033[38;2;223;142;29m\002(%s)\001\033[0m\002" "${branch}"
}
PS1='\[\e[38;2;30;102;245m\]\w\[\e[0m\]$(_prompt_git_branch)\n> '
set -o vi

# Starship prompt (set USE_STARSHIP=false to disable)
USE_STARSHIP="${USE_STARSHIP:-true}"
if [ "$USE_STARSHIP" = "true" ]; then
  eval "$(starship init bash)"
fi

toggle_starship() {
  if [ "${USE_STARSHIP:-true}" = "true" ]; then
    export USE_STARSHIP=false
  else
    export USE_STARSHIP=true
  fi
  source ~/.bashrc
}
alias toggle-starship="toggle_starship"

# fnm
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell bash)"
fi

export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$HOME/.dotnet:$PATH"

# unixODBC / msodbcsql18
export LD_LIBRARY_PATH="$HOME/.local/unixodbc/usr/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export ODBCSYSINI="$HOME/.local/mssql-tools18/etc"
export TZ='EST5EDT,M3.2.0,M11.1.0'

# Git aliases
alias g='git'
alias gst='git status'
alias gbr='git branch'
alias glo='git log --oneline --decorate'
alias glog='git log --oneline --decorate --graph'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gsw='git switch'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gd='git diff'
alias gds='git diff --staged'
alias gf='git fetch'
alias gl='git pull'
alias gpsh='git push'
alias grb='git rebase'
alias gsta='git stash'
alias gstp='git stash pop'
