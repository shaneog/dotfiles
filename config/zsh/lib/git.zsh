#!/usr/bin/env zsh

# The git aliases that actually get typed. The names and definitions are
# prezto's, so they are the ones the hands already know. Its git module defines
# about 150 more, and is not loaded.
#
# Adding one is a line here, a line in the test that lists them, and a row on
# the cheat sheet in guides/tools.html, which a test compares with this file.
alias g='git'
alias gia='git add'
alias gco='git checkout'
alias gbc='git checkout -b'
alias gfc='git clone'
alias gfr='git pull --rebase'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gr='git rebase'
