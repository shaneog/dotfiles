#!/usr/bin/env zsh

zinit ice from"gh-r" as"program" bpick"*arm*"
zinit light junegunn/fzf

zinit ice pick"bin/fzf-tmux" as"program" bpick"*arm*"
zinit light junegunn/fzf

# Create and bind multiple widgets using fzf. multisrc sources both files; the
# clone hook that used to run key-bindings.zsh could only fail, since the file
# ships non-executable and is meant to be sourced, not executed.
zinit ice multisrc"shell/{completion,key-bindings}.zsh" id-as"junegunn/fzf_completions" \
  pick"/dev/null"
zinit light junegunn/fzf

# Ignore gitignore with fzf
FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules}/*" 2> /dev/null'
FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
