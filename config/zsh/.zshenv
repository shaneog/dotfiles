#!/usr/bin/env zsh

# Profiling: enable when required
# zmodload zsh/zprof

# https://blog.patshead.com/2011/04/improve-your-oh-my-zsh-startup-time-maybe.html
skip_global_compinit=1
setopt noglobalrcs

# See https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache
export XDG_DATA_HOME=$HOME/.local/share

# zsh config. This has to be set before anything sources ${ZDOTDIR}/.zprofile,
# otherwise the fallback below reads $HOME/.zprofile instead of ours.
export ZDOTDIR=${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}
ZSH_CACHE_DIR=$XDG_CACHE_HOME/zsh
ZSH_COMPDUMP=$ZSH_CACHE_DIR/zcompdump

# Keep the path arrays free of duplicates. Here rather than in .zprofile,
# because this file is the only one every shell reads: a tmux pane is neither a
# login shell nor the first level, so it never sources .zprofile, and it still
# runs the additions at the end of this file on top of a PATH that already has
# them. The attribute is not inherited, so each shell has to set it for itself.
typeset -gU cdpath fpath path

# https://github.com/sorin-ionescu/prezto/blob/master/runcoms/zshenv
# Ensure that a non-login, non-interactive shell has a defined environment.
if [[ ( "$SHLVL" -eq 1 && ! -o LOGIN ) && -s "${ZDOTDIR}/.zprofile" ]]; then
  source "${ZDOTDIR}/.zprofile"
fi

# Ensure the zsh data diretory exists
[ ! -d "${XDG_DATA_HOME}/zsh" ] && mkdir -p "${XDG_DATA_HOME}/zsh"

# OrbStack CLI tools, when installed
[ -d "$HOME/.orbstack/bin" ] && path=("$HOME/.orbstack/bin" $path)

# Ensure we have the system directories in our PATH. `noglobalrcs` skips
# /etc/zprofile, so nothing else runs path_helper for us.
path=($path /usr/bin /bin /usr/sbin /sbin)

# Disable zsh_sessions
SHELL_SESSIONS_DISABLE=1
