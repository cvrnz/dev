export NVM_DIR="$HOME/.nvm"
# --no-use skips nvm's slow auto "nvm use default" (~15s+ on Git Bash, can hang).
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use  # This loads nvm
# Put the default node version on PATH directly (no subprocesses).
if [ -s "$NVM_DIR/alias/default" ]; then
  read -r _nvm_def < "$NVM_DIR/alias/default"
  _nvm_def="${_nvm_def#v}"
  for _nvm_bin in "$NVM_DIR"/versions/node/v"$_nvm_def"*/bin; do
    [ -d "$_nvm_bin" ] && _nvm_last="$_nvm_bin"
  done
  [ -n "$_nvm_last" ] && export PATH="$_nvm_last:$PATH"
  unset _nvm_def _nvm_bin _nvm_last
fi
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

alias b="nvim ~/.bashrc"
alias sb="source ~/.bashrc"
alias ll="ls -lahG"
alias h="history"
alias o="explorer ."
alias gst="git status"
alias gcl="git clone"
alias gcm="git commit -m"
alias gbr="git branch --no-pager"
alias glo="git log --oneline"
alias c="clear"

# Custom prompt: blue path, yellow git branch (if in a repo), then "> " on its own line
parse_git_branch() {
  git branch --show-current 2>/dev/null
}

set_bash_prompt() {
  local branch
  branch=$(parse_git_branch)
  PS1='\[\e[34m\]\w\[\e[0m\]'
  if [ -n "$branch" ]; then
    PS1+=' \[\e[33m\]'"$branch"'\[\e[0m\]'
  fi
  PS1+='\n\[\e[0m\]> '
}

PROMPT_COMMAND=set_bash_prompt

# Neovim (MSYS2 ucrt64 packages, extracted to %LOCALAPPDATA%\Programs\msys2)
_nvim_bin="$(cygpath -u "$LOCALAPPDATA")/Programs/msys2/ucrt64/bin"
[ -d "$_nvim_bin" ] && case ":$PATH:" in *":$_nvim_bin:"*) ;; *) export PATH="$PATH:$_nvim_bin" ;; esac
unset _nvim_bin
# Starship prompt (overrides the custom prompt above)
if ! command -v starship >/dev/null 2>&1 && [ -x "$LOCALAPPDATA/Programs/starship/starship.exe" ]; then
  export PATH="$(cygpath -u "$LOCALAPPDATA")/Programs/starship:$PATH"
fi
export STARSHIP_CONFIG="$(cygpath -w "$HOME/local/projects/dev/configs/starship.toml")"
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"