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
