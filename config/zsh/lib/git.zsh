#!/usr/bin/env zsh

# The git aliases that actually get typed. The names and definitions are
# prezto's, so they are the ones the hands already know.
#
# Prezto's git module itself is not loaded. It defines about 150 aliases, and
# several of them call helper functions (git-branch-current and its siblings)
# that a zinit snippet never puts on fpath, so they fail when used. It would
# also be one more upstream tracked at HEAD and sourced into every shell.
#
# Defined eagerly rather than deferred: nine aliases cost nothing to define.
# Adding one is a line here and a line in the test that lists them.
alias g='git'
alias gia='git add'
alias gco='git checkout'
alias gbc='git checkout -b'
alias gfc='git clone'
alias gfr='git pull --rebase'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gr='git rebase'
