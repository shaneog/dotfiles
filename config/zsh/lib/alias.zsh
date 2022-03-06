#!/usr/bin/env zsh

# Check external IP from command line
alias checkip='curl "http://checkip.amazonaws.com"'

# Use only neovim
alias vim='nvim'
alias vi='nvim'

# Recursively delete node_modules directories
alias rm_node_modules="find . -name 'node_modules' -type d -prune -print -exec rm -rf '{}' \;"
