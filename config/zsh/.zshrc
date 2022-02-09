# amd64 or arm64
ARCH=$(uname -m)
[ $ARCH = "x86_64" ] && ARCH="amd64"

# Set HISTFILE location
[ ! -d "${XDG_DATA_HOME}/zsh" ] && mkdir "${XDG_DATA_HOME}/zsh"
export HISTFILE=$XDG_DATA_HOME/zsh/zhistory

# Check if zplug is installed
if [[ ! -d $HOME/.zplug ]]; then
  git clone -q --depth 1 https://github.com/zplug/zplug $HOME/.zplug
  source $HOME/.zplug/init.zsh
fi

# zplug
source $HOME/.zplug/init.zsh
# Let zplug manage zplug
zplug 'zplug/zplug', hook-build:'zplug --self-manage'

# Make sure to use double quotes to prevent shell expansion
zplug "zsh-users/zsh-completions"
zplug "zsh-users/zsh-syntax-highlighting", defer:2
zplug "zsh-users/zsh-history-substring-search", defer:3
zplug "junegunn/fzf", \
  as:command, \
  from:gh-r, \
  rename-to:fzf, \
  use:"*${(L)$(uname -s)}*${ARCH}*"
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
zplug "greymd/docker-zsh-completion"

# Prezto modules
zplug 'modules/environment', from:prezto
zplug 'modules/terminal', from:prezto
zplug 'modules/editor', from:prezto
zplug 'modules/directory', from:prezto
zplug 'modules/history', from:prezto
zplug 'modules/spectrum', from:prezto
zplug 'modules/gnu-utility', from:prezto
zplug 'modules/utility', from:prezto
zplug 'modules/completion', from:prezto
zplug 'modules/homebrew', from:prezto
zplug 'modules/git', from:prezto
zplug 'modules/osx', from:prezto
zplug 'modules/tmux', from:prezto

# Prezto configuration options
zstyle ':prezto:*:*' color 'yes'
zstyle ':prezto:module:editor' dot-expansion 'yes'
zstyle ':prezto:module:terminal' auto-title 'yes'
zstyle ':prezto:module:tmux:iterm' integrate 'no'

# Spaceship
zplug 'denysdovhan/spaceship-prompt', \
  use:spaceship.zsh, \
  from:github, \
  as:theme

export SPACESHIP_GIT_STATUS_PREFIX=" "
export SPACESHIP_GIT_STATUS_SUFFIX=""
export SPACESHIP_GIT_STATUS_ADDED="%F{yellow}•%F{red}"
export SPACESHIP_GIT_STATUS_UNTRACKED="%F{blue}•%F{red}"
export SPACESHIP_GIT_STATUS_DELETED="%F{red}•%F{red}"
export SPACESHIP_GIT_STATUS_MODIFIED="%F{green}•%F{green}"

# Install packages that have not been installed yet
if ! zplug check --verbose; then
  echo; zplug install
fi

zplug load

# set autoload path
fpath=($ZDOTDIR/lib "${fpath[@]}")

# autoload all homemade functions
autoload -Uz $fpath[1]/*(.:t)

# Add zplug bin directory to PATH
export PATH=$HOME/.zplug/bin:$PATH

# History options (must come after prezto modules/history)
[ "$HISTSIZE" -lt 50000 ] && HISTSIZE=50000
[ "$SAVEHIST" -lt 100000 ] && SAVEHIST=100000

## History command configuration
setopt INC_APPEND_HISTORY     # append into history file
setopt HIST_REDUCE_BLANKS     ## Delete empty lines from history file
setopt HIST_NO_STORE          ## Do not add history and fc commands to the history

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

# Ignore gitignore with fzf
export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules}/*" 2> /dev/null'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Fix for https://openradar.appspot.com/27348363
ssh-add -A 2>/dev/null

# GnuPG fix
export GPG_TTY=$(tty)

###
# Utilities
###

# Python pyenv
# Set the root outside the if to handle the install stage
export PYENV_ROOT="$XDG_DATA_HOME/pyenv"
if [[ -x "$(command -v pyenv)" ]]; then
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init --path)"

  eval "$(pyenv init -)"
fi

# nodenv - NodeJS version manager
if [[ -x "$(command -v nodenv)" ]]; then
  eval "$(nodenv init -)"  
fi

###
# Aliases
###

# Tmux
alias tmux="tmux -f ${XDG_CONFIG_HOME}/tmux/tmux.conf"

# Check external IP from command line
alias checkip='curl "http://checkip.amazonaws.com"'

# Use only neovim
alias vim='nvim'
alias vi='nvim'

# Recursively delete node_modules directories
alias rm_node_modules="find . -name 'node_modules' -type d -prune -print -exec rm -rf '{}' \;"

###
# 
###

# Opt-out of homebrew analytics
export HOMEBREW_NO_ANALYTICS=1

# Automatically launch a tmux session, unless TMUX is already set or TERM_PROGRAM is set to vscode
if [[ -z "$TMUX" ]] && [[ "$TERM_PROGRAM" != "vscode" ]]; then
  case $- in *i*)
    tmux_session="$(echo $USER | tr -d '.')"

    if tmux has-session -t "$tmux_session" 2>/dev/null; then
      tmux attach-session -t "$tmux_session"
    else
      tmux new-session -s "$tmux_session"
    fi
  esac
fi

# Use a local zshrc, if exists
if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi
