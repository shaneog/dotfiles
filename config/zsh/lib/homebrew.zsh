#!/usr/bin/env zsh

zinit snippet PZTM::homebrew

# The whole maintenance run in one word. Defined after the snippet above, not in
# alias.zsh: that file loads first, so an alias there would be replaced without a
# word if prezto ever took the same name -- it already owns brewc, brewi, brewl,
# brewo, brews, brewu and brewx.
#
# Semicolons rather than &&: `brew doctor` exits non-zero for warnings that are
# not failures, and a cleanup is still wanted when an upgrade fails.
alias brewup='brew update; brew upgrade; brew cleanup; brew doctor'

# shellenv lives in .zprofile, not here: this file is sourced two thirds of the
# way down .zshrc, and things above it -- the tmux autostart in particular --
# test for Homebrew's binaries with $+commands.
[[ -n "$HOMEBREW_PREFIX" ]] \
  && FPATH="${HOMEBREW_PREFIX}/share/zsh/site-functions:${FPATH}"
