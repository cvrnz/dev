# env
export ANDROID_HOME="$HOME/Library/Android/sdk"
export NDK_HOME="$ANDROID_HOME/ndk/29.0.13846066"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
export ASDF_DATA_DIR="$HOME/.asdf"

# path
export PATH="$HOME/.local/bin:$HOME/go/bin:$ASDF_DATA_DIR/shims:$PATH"
export PATH="$PATH:$ANDROID_HOME/platform-tools:$JAVA_HOME/bin"

# fnm
eval "$(fnm env --use-on-cd --shell zsh)"

# prompt: starship when installed, otherwise a plain prompt with the git branch
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
else
  setopt PROMPT_SUBST
  _prompt_git_branch() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return
    printf " %%{\033[38;2;223;142;29m%%}(%s)%%{\033[0m%%}" "${branch}"
  }
  PS1=$'%{\e[38;2;30;102;245m%}%~%{\e[0m%}$(_prompt_git_branch)\n> '
fi

# vi mode
bindkey -v

# alias: shell
alias z="code ~/.zshrc"
alias sz="source ~/.zshrc"
alias n="nvim"
alias c="clear"
alias h="history"
alias ll="ls -lahG"
alias path='echo -e ${PATH//:/\\n}'

# alias: navigation
alias dsk="cd ~/Desktop"
alias dev="cd ~/Developer"

# alias: macos
alias o="open ."
alias saf="defaults write com.apple.finder AppleShowAllFiles YES; killall Finder"
alias haf="defaults write com.apple.finder AppleShowAllFiles NO; killall Finder"

# alias: media
alias ytdl="yt-dlp --extract-audio --audio-format aac --audio-quality 0"

# alias: git
alias gst="git status"
alias gcl="git clone"
alias gcm="git commit -m"
alias gbr="git --no-pager branch"
alias glo="git log --oneline"
alias gct='git commit -m "$(date -u +"%Y-%m-%d %H:%M:%S UTC")"'
alias gclean="git clean -df && git checkout ."

# Clone a repo and strip the git history (degit-style)
gclone() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: gclone <repo-url> <folder-name>"
    return 1
  fi
  git clone --depth 1 "$1" "$2" && rm -rf "$2"/.git
  echo "Successfully cloned into '$2' and removed .git history."
}

# local overrides and secrets (not in this repo), e.g. GITHUB_READ_PACKAGES_TOKEN
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
