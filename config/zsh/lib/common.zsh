#!/usr/bin/env zsh

##
# Plugins
##
zinit wait lucid for \
  atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
  blockf \
    zsh-users/zsh-completions \
  atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions

# http://zshwiki.org/home/config/prompt
# enable colors and predefined variables
autoload -Uz colors && colors

##
# Prezto
##

# Prezto Settings
zstyle ':prezto:*:*' color 'yes'
zstyle ':prezto:module:editor' dot-expansion 'yes'
zstyle ':prezto:module:terminal' auto-title 'yes'
zstyle ':prezto:module:tmux:iterm' integrate 'no'
zstyle ':prezto:module:utility' correct 'no'
zstyle ':prezto:module:utility' safe-ops 'no'

# Prezto modules
zinit wait lucid for \
  PZTM::environment \
  PZTM::terminal \
  PZTM::editor \
  PZTM::directory \
  PZTM::spectrum \
  PZTM::gnu-utility
zinit ice svn; zinit snippet PZTM::utility
zinit ice svn blockf \
  atclone"git clone -q --recursive https://github.com/zsh-users/zsh-completions.git external"
zinit snippet PZTM::completion

##
# Configuration
##

# Enable zsh corrections
setopt CORRECT

# Environment
EDITOR="nvim"
VISUAL=$VISUAL
PAGER="less"

# Default less options
# Mouse-wheel scrolling has been disabled by -X (disable screen clearing).
LESS="-F -g -i -M -R -S -w -X -z-4"

# Fix for https://openradar.appspot.com/27348363
ssh-add -A 2>/dev/null

# GnuPG fix
GPG_TTY=$(tty)
