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

# https://starship.rs -- comes from the Brewfile, which also installs its
# completions into Homebrew's site-functions. Its init is cached rather than
# regenerated on every shell.
cached_init starship starship init zsh && source $REPLY
