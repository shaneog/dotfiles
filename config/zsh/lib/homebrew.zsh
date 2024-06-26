#!/usr/bin/env zsh

zinit snippet PZTM::homebrew

FPATH="${HOMEBREW_PREFIX}/share/zsh/site-functions:${FPATH}"

# Opt-out of homebrew analytics
HOMEBREW_NO_ANALYTICS=true
# Don't show homebrew environment hints
HOMEBREW_NO_ENV_HINTS=true
