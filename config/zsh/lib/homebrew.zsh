#!/usr/bin/env zsh

zinit snippet PZTM::homebrew

FPATH="${HOMEBREW_PREFIX}/share/zsh/site-functions:${FPATH}"

# Set homebrew shellenv
if [ -d "/opt/homebrew" ]; then
  HOMEBREW_PREFIX="/opt/homebrew";
  HOMEBREW_CELLAR="/opt/homebrew/Cellar";
  HOMEBREW_REPOSITORY="/opt/homebrew";
  PATH="/opt/homebrew/bin:/opt/homebrew/sbin${PATH+:$PATH}";
  MANPATH="/opt/homebrew/share/man${MANPATH+:$MANPATH}:";
  INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}";
fi
