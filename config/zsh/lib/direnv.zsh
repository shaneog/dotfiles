#!/usr/bin/env zsh

zinit from"gh-r" as"program" bpick"*arm*" mv"direnv* -> direnv" \
  atclone'./direnv hook zsh > zhook.zsh' atpull'%atclone' \
  pick"direnv" src="zhook.zsh" for \
    direnv/direnv
