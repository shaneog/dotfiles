#!/usr/bin/env zsh

# A dumb terminal (Emacs shell-mode, some CI) has no cursor control, and
# starship errors on every prompt there. Leave zsh's default prompt alone.
[[ "$TERM" == "dumb" ]] && return

# Tear down a prompt the base layer may have installed. starship overwrites
# $PROMPT regardless, but pure's hooks would go on running async git work for a
# prompt that is no longer drawn.
if (( $+functions[prompt_pure_precmd] )); then
  autoload -Uz add-zsh-hook
  (( $+functions[prompt] )) && prompt off 2>/dev/null
  add-zsh-hook -d precmd prompt_pure_precmd
  add-zsh-hook -d preexec prompt_pure_preexec
fi

# https://starship.rs
zinit ice as"program" bpick"*aarch64*.tar.gz"  from"gh-r" \
  atclone"./starship init zsh > init.zsh; ./starship completions zsh > _starship" \
  atpull"%atclone" src"init.zsh"
zinit light starship/starship
