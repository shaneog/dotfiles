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
zinit ice wait lucid
zinit light MichaelAquilina/zsh-you-should-use

# Check external IP from command line
alias checkip='curl "http://checkip.amazonaws.com"'

# Use only neovim
alias vim='nvim'
alias vi='nvim'

# Recursively delete node_modules directories
alias rm_node_modules="find . -name 'node_modules' -type d -prune -print -exec rm -rf '{}' \;"

# remove compiled scripts
alias rm_zcompile="find . -name '*.zwc*' -type f -delete"
