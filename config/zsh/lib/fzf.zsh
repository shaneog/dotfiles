#!/usr/bin/env zsh

zinit ice lucid wait from"gh-r" as"program" bpick"*arm*"
zinit load junegunn/fzf

zinit ice lucid wait pick"bin/fzf-tmux" as"program" bpick"*arm*"
zinit load junegunn/fzf

# Create and bind multiple widgets using fzf
zinit ice lucid wait atclone"shell/key-bindings.zsh" \
  atpull"%atclone" multisrc"shell/{completion,key-bindings}.zsh" id-as"junegunn/fzf_completions" \
  pick"/dev/null"
zinit load junegunn/fzf

# Ignore gitignore with fzf
FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules}/*" 2> /dev/null'
FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
