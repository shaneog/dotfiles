#!/usr/bin/env zsh

# https://starship.rs
zinit ice lucid as"program" bpick"*aarch64*"  from"gh-r" \
  atclone"./starship init zsh > init.zsh; ./starship completions zsh > _starship" \
  atpull"%atclone" src"init.zsh"
zinit load starship/starship
