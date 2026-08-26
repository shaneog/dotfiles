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

# Set homebrew shellenv, unless the base layer already did it
if [ -z "${HOMEBREW_PREFIX}" ] && [ -d "/opt/homebrew" ]; then
  HOMEBREW_PREFIX="/opt/homebrew";
  HOMEBREW_CELLAR="/opt/homebrew/Cellar";
  HOMEBREW_REPOSITORY="/opt/homebrew";
  PATH="/opt/homebrew/bin:/opt/homebrew/sbin${PATH+:$PATH}";
  MANPATH="/opt/homebrew/share/man${MANPATH+:$MANPATH}:";
  INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}";
fi

FPATH="${HOMEBREW_PREFIX}/share/zsh/site-functions:${FPATH}"
