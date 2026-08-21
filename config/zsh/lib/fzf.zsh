#!/usr/bin/env zsh

# fzf comes from the Brewfile, which also ships fzf-tmux and the completions.
# `fzf --zsh` emits both the completion and key-binding integration.
cached_init fzf fzf --zsh && source $REPLY

# Ignore gitignore with fzf
FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules}/*" 2> /dev/null'
FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
