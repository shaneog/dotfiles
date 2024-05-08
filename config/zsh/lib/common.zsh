#!/usr/bin/env zsh

##
# Plugins
##
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light zdharma-continuum/fast-syntax-highlighting

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
zinit for \
  PZTM::environment \
  PZTM::terminal \
  PZTM::editor \
  PZTM::directory \
  PZTM::spectrum \
  PZTM::gnu-utility
zinit snippet PZTM::utility
zinit ice blockf \
  atclone"git clone -q --depth=1 https://github.com/zsh-users/zsh-completions.git external"
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
ssh-add --apple-load-keychain 2>/dev/null
