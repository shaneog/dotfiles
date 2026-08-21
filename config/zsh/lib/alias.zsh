#!/usr/bin/env zsh

# Show tips for configured aliases
zinit ice from"gh-r" as"program" bpick"*arm64*"
zinit light decayofmind/zsh-fast-alias-tips

# Check external IP from command line
alias checkip='curl "http://checkip.amazonaws.com"'

# Use only neovim
alias vim='nvim'
alias vi='nvim'

# Recursively delete node_modules directories
alias rm_node_modules="find . -name 'node_modules' -type d -prune -print -exec rm -rf '{}' \;"

# remove compiled scripts
alias rm_zcompile="find . -name '*.zwc*' -type f -delete"
