#!/usr/bin/env zsh

# Enable zsh corrections
setopt CORRECT

# Environment
export EDITOR='nvim'
export VISUAL='nvim'
export PAGER='less'

# Default less options
# Mouse-wheel scrolling has been disabled by -X (disable screen clearing).
export LESS='-F -g -i -M -R -S -w -X -z-4'

# Fix for https://openradar.appspot.com/27348363
ssh-add -A 2>/dev/null

# GnuPG fix
export GPG_TTY=$(tty)
