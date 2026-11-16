#!/usr/bin/env zsh

# Point out when a command already has an alias.
#
# Pure zsh, deliberately: the previous plugin shipped a prebuilt Go binary
# fetched from GitHub releases, which meant a first shell on a new machine did
# network I/O, and an unverified binary from a fifteen-star project with one
# three-year-old release ran in every interactive shell. zinit does not check the
# published checksums.
#
# Deferred: sourcing it eagerly cost 47ms of startup (237ms against 190ms),
# which is absurd for something that only matters once you have typed a command.
# Loading it after the first prompt brings that back to 197ms.
zinit ice wait lucid ver"$DOTFILES_PINS[MichaelAquilina/zsh-you-should-use]"
zinit light MichaelAquilina/zsh-you-should-use

##
# Standard commands, with the flags that are always wanted
##

# ls in colour. macOS has BSD ls at /bin/ls, which takes -G and reads LSCOLORS;
# any other ls takes --color.
if [[ $OSTYPE == darwin* && $commands[ls] == /bin/ls ]]; then
  export LSCOLORS=${LSCOLORS:-exfxcxdxbxGxDxabagacad}
  alias ls='ls -G'
else
  alias ls='ls --group-directories-first --color=auto'
fi

# BSD grep reads the first of these and GNU grep the second.
export GREP_COLOR=${GREP_COLOR:-'37;45'}
export GREP_COLORS=${GREP_COLORS:-"mt=$GREP_COLOR"}
alias grep='grep --color=auto'

alias mkdir='mkdir -p'
alias df='df -kh'
alias du='du -kh'

# These take patterns of their own, which zsh would otherwise expand first:
# `find . -name *.md` finds nothing once a file here matches, and a remote
# path with a * in it is an error before scp ever sees it.
alias find='noglob find'
alias scp='noglob scp'
alias sftp='noglob sftp'

##
# Short names
##

alias l='ls -1A'         # One column, hidden files too.
alias ll='ls -lh'        # Long, with sizes a person can read.
alias d='dirs -v'        # The directory stack that AUTO_PUSHD keeps.
alias p='${(z)PAGER}'
(( $+commands[open] )) && alias o='open'

# Check external IP from command line
alias checkip='curl "http://checkip.amazonaws.com"'

# Use only neovim
alias vim='nvim'
alias vi='nvim'

# Recursively delete node_modules directories
alias rm_node_modules="find . -name 'node_modules' -type d -prune -print -exec rm -rf '{}' \;"

# remove compiled scripts
alias rm_zcompile="find . -name '*.zwc*' -type f -delete"
