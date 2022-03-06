#!/usr/bin/env zsh

# Profiling: enable when required
# zmodload zsh/zprof

# https://blog.patshead.com/2011/04/improve-your-oh-my-zsh-startup-time-maybe.html
skip_global_compinit=1
setopt noglobalrcs

# https://github.com/sorin-ionescu/prezto/blob/master/runcoms/zshenv
# Ensure that a non-login, non-interactive shell has a defined environment.
if [[ ( "$SHLVL" -eq 1 && ! -o LOGIN ) && -s "${ZDOTDIR:-$HOME}/.zprofile" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprofile"
fi

# See https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
XDG_CONFIG_HOME=$HOME/.config
XDG_CACHE_HOME=$HOME/.cache
XDG_DATA_HOME=$HOME/.local/share

# zsh config
ZDOTDIR=$XDG_CONFIG_HOME/zsh
ZSH_CACHE_DIR=$XDG_CACHE_HOME/zsh
ZSH_COMPDUMP=$ZSH_CACHE_DIR/zcompdump

# Ensure the zsh data diretory exists
[ ! -d "${XDG_DATA_HOME}/zsh" ] && mkdir -p "${XDG_DATA_HOME}/zsh"

# Ensure we have sbin in our PATH
PATH=$PATH:/usr/sbin:/sbin

# Set homebrew shellenv
if [ -d "/opt/homebrew" ]; then
  HOMEBREW_PREFIX="/opt/homebrew";
  HOMEBREW_CELLAR="/opt/homebrew/Cellar";
  HOMEBREW_REPOSITORY="/opt/homebrew";
  PATH="/opt/homebrew/bin:/opt/homebrew/sbin${PATH+:$PATH}";
  MANPATH="/opt/homebrew/share/man${MANPATH+:$MANPATH}:";
  INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}";
fi

# Disable zsh_sessions
SHELL_SESSIONS_DISABLE=1
