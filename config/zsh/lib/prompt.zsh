#!/usr/bin/env zsh

# https://starship.rs
zinit ice as"program" bpick"*aarch64*"  from"gh-r" \
  atclone"./starship init zsh > init.zsh; ./starship completions zsh > _starship" \
  atpull"%atclone" src"init.zsh"
zinit light starship/starship
