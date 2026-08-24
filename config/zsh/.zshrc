#!/usr/bin/env zsh

# Guard against double-sourcing, in case $HOME/.zshrc also sources this file.
[[ -n "$__DOTFILES_ZSHRC" ]] && return
__DOTFILES_ZSHRC=1

##
# tmux
##
# Attach (or start) a session before anything below runs, so the outer shell
# doesn't pay for an init it is about to replace; the rest of this file runs on
# detach. fpath is prepended again further down, which is where the rest of the
# autoloaded functions are declared.
fpath=($ZDOTDIR/autoload "${fpath[@]}")
autoload -Uz tmux_autostart
tmux_autostart

##
# Base layer
##
# Layer on top of an existing rc file, if there is one, so anything configured
# below wins. Guard: when ZDOTDIR is unset this file *is* $HOME/.zshrc, and
# sourcing it would recurse.
__dotfiles_zdotdir=${${ZDOTDIR:-$HOME}:A}
if [[ "$__dotfiles_zdotdir" != "${HOME:A}" && -r "$HOME/.zshrc" ]]; then
  source "$HOME/.zshrc"
fi
unset __dotfiles_zdotdir

##
# Zinit
##
declare -A ZINIT
ZINIT[ZINIT_HOME]="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit"
ZINIT[ZCOMPDUMP_PATH]=$ZSH_COMPDUMP
# Check for and install if necessary
if [[ ! -d $ZINIT[ZINIT_HOME] ]]; then
  echo "Installing zinit..."
  mkdir -p "$(dirname $ZINIT[ZINIT_HOME])"
  git clone -q https://github.com/zdharma-continuum/zinit.git "$ZINIT[ZINIT_HOME]"
fi
# Bootstrap zinit
source "${ZINIT[ZINIT_HOME]}/zinit.zsh"

# Load all the auto-completions, has to be done before any compdefs
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

##
# Set up autoloaded functions
##
fpath=($ZDOTDIR/autoload "${fpath[@]}")
autoload -Uz $fpath[1]/*(.:t)

##
# Load custom scripts
##
custom_lib=${ZDOTDIR}/lib
if [[ -d "$custom_lib" ]]; then
  for file in $custom_lib/*.zsh; do
    source $file
   done
fi
unset custom_lib

# https://carlosbecker.com/posts/speeding-up-zsh
# see glob details here: https://gist.github.com/ctechols/ca1035271ad134841284
autoload -Uz compinit
# Unconditionally: the branch below only regenerates a dump that already exists,
# so without this the directory is never created, the dump is never written, and
# every shell pays for a full compinit.
mkdir -p "$ZSH_COMPDUMP:h"
if [[ -n ${ZSH_COMPDUMP}(#qN.mh+20) ]]; then
  compinit -i -d "$ZSH_COMPDUMP";
  # Keep $ZSH_COMPDUMP younger than cache time even if it isn't regenerated.
  touch "$ZSH_COMPDUMP"
else
  compinit -C -d "$ZSH_COMPDUMP";
fi

zinit cdreplay -q

# compinit above resets $_comps, which drops completions the base layer
# registered through bashcompinit. Re-register the ones we know about.
if (( $+commands[aws_completer] )) && (( ! $+_comps[aws] )); then
  autoload -Uz bashcompinit && bashcompinit
  complete -C "$commands[aws_completer]" aws
fi

##
# Syntax highlighting
##
# zsh-patina comes from the Brewfile. Activated here rather than from lib/
# because its README asks for the end of .zshrc, and because it wants to be the
# last thing hooking line-pre-redraw.
#
# The one tool here that pays a subprocess per shell: its own output says not to
# cache it, so cached_init is deliberately not used. Roughly 8ms for `activate`
# plus a millisecond to eval, once its background daemon is warm.
if (( $+commands[zsh-patina] )); then
  # A base layer may already have loaded zsh-syntax-highlighting on the same
  # hook, and two highlighters fighting over the line editor shows up as
  # flicker. Emptying its highlighter list stands it down, which is documented
  # behavior and does not depend on the version or how it registered itself.
  (( $+functions[_zsh_highlight] )) && ZSH_HIGHLIGHT_HIGHLIGHTERS=()
  eval "$(zsh-patina activate)"
fi

# Use a local zshrc, if exists
if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi

# Set the PATH for macOS
[[ -x /bin/launchctl ]] && /bin/launchctl setenv PATH $PATH
