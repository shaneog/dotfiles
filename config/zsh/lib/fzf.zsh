#!/usr/bin/env zsh

zinit ice from"gh-r" as"program" bpick"*arm*"
zinit light junegunn/fzf

zinit ice pick"bin/fzf-tmux" as"program" bpick"*arm*"
zinit light junegunn/fzf

# Create and bind multiple widgets using fzf
zinit ice atclone"shell/key-bindings.zsh" \
  atpull"%atclone" multisrc"shell/{completion,key-bindings}.zsh" id-as"junegunn/fzf_completions" \
  pick"/dev/null"
zinit light junegunn/fzf

# Ignore gitignore with fzf
FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules}/*" 2> /dev/null'
FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
