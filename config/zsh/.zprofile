#
# Executes commands at login before zshrc.

##
# Base layer
##
# Layer on top of an existing profile, if there is one, so anything set below
# wins. Guard: when ZDOTDIR is unset this file *is* $HOME/.zprofile, and
# sourcing it would recurse.
__dotfiles_zdotdir=${${ZDOTDIR:-$HOME}:A}
if [[ "$__dotfiles_zdotdir" != "${HOME:A}" && -r "$HOME/.zprofile" ]]; then
  source "$HOME/.zprofile"
fi
unset __dotfiles_zdotdir

# Set locale correctly
if [[ -z "$LANG" ]]; then
  LANG='en_US.UTF-8'
  LANGUAGE=$LANG
fi

LC_COLLATE=$LANG
LC_CTYPE=$LANG
LC_MESSAGES=$LANG
LC_MONETARY=$LANG
LC_NUMERIC=$LANG
LC_TIME=$LANG
LC_ALL=$LANG

LESSCHARSET=utf-8

# Ensure path arrays do not contain duplicates. Also dedupes anything the base
# layer above added.
typeset -gU cdpath fpath path

# Zsh search path for executables. Prepend only what is missing, so we don't
# reorder a PATH that was already arranged elsewhere: a base profile may
# deliberately put Homebrew ahead of /usr/local.
for __dotfiles_dir in /usr/local/bin /usr/local/sbin; do
  (( ${path[(Ie)$__dotfiles_dir]} )) || path=("$__dotfiles_dir" $path)
done
unset __dotfiles_dir

# Homebrew, before .zshrc runs. Not in lib/homebrew.zsh with the rest of the
# Homebrew wiring: that file is sourced two thirds of the way down .zshrc, and
# the tmux autostart at the top of it asks $+commands[tmux] -- which answers 0,
# silently, on a machine where nothing else has put Homebrew on PATH yet. With a
# managed base layer underneath there is always something else, which is what
# hid this.
#
# Guarded on HOMEBREW_PREFIX so a base layer that has already arranged its own
# order keeps it. Prepended after /usr/local above, so Homebrew wins, which is
# what `brew shellenv` itself does.
if [ -z "${HOMEBREW_PREFIX}" ] && [ -d "/opt/homebrew" ]; then
  export HOMEBREW_PREFIX="/opt/homebrew"
  export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
  export HOMEBREW_REPOSITORY="/opt/homebrew"
  path=("$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin" $path)
  export MANPATH="$HOMEBREW_PREFIX/share/man${MANPATH+:$MANPATH}:"
  export INFOPATH="$HOMEBREW_PREFIX/share/info:${INFOPATH:-}"
fi
