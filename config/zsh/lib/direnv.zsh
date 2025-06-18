#!/usr/bin/env zsh

zinit from"gh-r" as"program" bpick"*arm64*" mv"direnv* -> direnv" \
  atclone'./direnv hook zsh > zhook.zsh' atpull'%atclone' \
  pick"direnv" src="zhook.zsh" for \
  direnv/direnv
