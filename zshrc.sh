# Language
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

# XDG
export XDG_CONFIG_HOME="$HOME/.config/"

# Check if zplug is installed
if [[ ! -d ~/.zplug ]]; then
  git clone --depth 1 https://github.com/zplug/zplug ~/.zplug
  source ~/.zplug/init.zsh
fi

# Essential
source ~/.zplug/init.zsh
# Let zplug manage zplug
zplug 'zplug/zplug', hook-build:'zplug --self-manage'

# Make sure to use double quotes to prevent shell expansion
zplug "zsh-users/zsh-completions"
zplug "zsh-users/zsh-syntax-highlighting", defer:2
zplug "zsh-users/zsh-history-substring-search", defer:3
zplug "junegunn/fzf-bin", \
  as:command, \
  from:gh-r, \
  rename-to:fzf, \
  use:"*${(L)$(uname -s)}*amd64*"
zplug "junegunn/fzf", \
  as:command, \
  use:"bin/fzf-tmux"
zplug "junegunn/fzf", \
  use:"shell/*.zsh"
zplug "zchee/go-zsh-completions"
zplug "zsh-users/zsh-autosuggestions", \
  use:"zsh-autosuggestions.zsh"

export ZSH_AUTOSUGGEST_USE_ASYNC=1

# Tips for unused aliases
zplug "djui/alias-tips"
export ZSH_PLUGINS_ALIAS_TIPS_TEXT="💡  Try: "

# Docker completions
zplug "docker/cli", use:contrib/completion/zsh
zplug "docker/compose", use:contrib/completion/zsh

# Prezto modules
zplug 'modules/environment', from:prezto
zplug 'modules/terminal', from:prezto
zplug 'modules/editor', from:prezto
zplug 'modules/history', from:prezto
zplug 'modules/directory', from:prezto
zplug 'modules/spectrum', from:prezto
zplug 'modules/utility', from:prezto
zplug 'modules/completion', from:prezto
zplug 'modules/homebrew', from:prezto
zplug 'modules/git', from:prezto
zplug 'modules/osx', from:prezto
zplug 'modules/ruby', from:prezto
zplug 'modules/rails', from:prezto
zplug 'modules/tmux', from:prezto
zplug 'modules/prompt', from:prezto

# Tmux
alias tmux="tmux -f ${HOME}/.config/tmux/tmux.conf"


# Prezto configuration options
zstyle ':prezto:*:*' color 'yes'
zstyle ':prezto:module:editor' dot-expansion 'yes'
zstyle ':prezto:module:prompt' theme 'sorin'
zstyle ':prezto:module:terminal' auto-title 'yes'
zstyle ':prezto:module:tmux:iterm' integrate 'no'
zstyle ':prezto:module:ruby:chruby' auto-switch 'yes'

# Install packages that have not been installed yet
if ! zplug check --verbose; then
  echo; zplug install
fi

zplug load

# Add zplug bin directory to PATH
export PATH=$HOME/.zplug/bin:$PATH

# Environment
export EDITOR='nvim'
export VISUAL='nvim'
export PAGER='less'

# Default less options
# Mouse-wheel scrolling has been disabled by -X (disable screen clearing).
export LESS='-F -g -i -M -R -S -w -X -z-4'


ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor root)
# zsh-history-substring-search
if zplug check "zsh-users/zsh-history-substring-search"; then
  zmodload zsh/terminfo
  [ -n "${terminfo[kcuu1]}" ] && bindkey "${terminfo[kcuu1]}" history-substring-search-up
  [ -n "${terminfo[kcud1]}" ] && bindkey "${terminfo[kcud1]}" history-substring-search-down
  bindkey -M emacs '^P' history-substring-search-up
  bindkey -M emacs '^N' history-substring-search-down
  bindkey -M vicmd 'k' history-substring-search-up
  bindkey -M vicmd 'j' history-substring-search-down
fi

# Use a local zshrc, if exists
if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi

# Ignore gitignore with fzf
export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules}/*" 2> /dev/null'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Google Cloud SDK.
if [[ -x "$(command -v gcloud)" ]]; then
  source "$(brew --prefix)/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
  source "$(brew --prefix)/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc"
fi

# Kubernetes
if [[ -x "$(command -v kubectl)" ]]; then
  source <(kubectl completion zsh)
fi

# Go
if [[ -x "$(command -v go)" ]]; then
  GOROOT="$(brew --prefix)/opt/go/libexec/bin"
  export GOPATH="$HOME/.go"
  export PATH=$PATH:$GOROOT:$GOPATH/bin
fi

# Postgres.app
if [[ -d /Applications/Postgres.app ]]; then
  export PATH=$PATH:/Applications/Postgres.app/Contents/Versions/latest/bin
fi

# Python virtualenwrapper
if [[ -x "$(command -v virtualenv)" ]]; then
  source "$(brew --prefix)/bin/virtualenvwrapper.sh"
fi

# Fix for https://openradar.appspot.com/27348363
ssh-add -A 2>/dev/null

# Java environments
if [[ -x "$(command -v jenv)" ]]; then
  export JENV_ROOT=/usr/local/var/jenv
  eval "$(jenv init -)"
fi

# Local bin directory
export PATH=$HOME/.bin:$PATH

# Yarn bin
if [[ -x "$(command -v yarn)" ]]; then
  export PATH="$HOME/.yarn/bin:$PATH"
fi

# Automatically launch a tmux session
if [[ -z "$TMUX" ]]; then
  tmux_session="$(echo $USER | tr -d '.')"

  if tmux has-session -t "$tmux_session" 2>/dev/null; then
    tmux attach-session -t "$tmux_session"
  else
    tmux new-session -s "$tmux_session"
  fi

  # if ! tmux has-session -t "$tmux_session" 2> /dev/null; then
  #   # Disable the destruction of unattached sessions globally.
  #   tmux set-option -g destroy-unattached off &> /dev/null

  #   # Create a new session.
  #   tmux new-session -d -s "$tmux_session"

  #   # Disable the destruction of the new, unattached session.
  #   tmux set-option -t "$tmux_session" destroy-unattached off &> /dev/null

  #   # Enable the destruction of unattached sessions globally to prevent
  #   # an abundance of open, detached sessions.
  #   tmux set-option -g destroy-unattached on &> /dev/null
  # fi

  # exec tmux new-session -t "$tmux_session"
fi

# Allow removal of IP addresses from the SSH known_hosts file. This is useful for
# rapidly changing cloud servers which may receive a previously seen IP.
function rm_known_host() {
  if [ -n "$1" ]
  then
    sed -i'' "/$1/d" "$HOME/.ssh/known_hosts"
  fi
}

# Check external IP from command line
alias checkip='curl "http://checkip.amazonaws.com"'

# Use only noevim
alias vim='nvim'
alias vi='vim'

# GnuPG fix
export GPG_TTY=$(tty)
