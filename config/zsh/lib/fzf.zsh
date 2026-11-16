#!/usr/bin/env zsh

# fzf comes from the Brewfile, which also ships fzf-tmux and the completions.
# `fzf --zsh` emits both the completion and key-binding integration.
cached_init fzf fzf --zsh && source $REPLY

# fzf's built-in default is `find`, which is slow and cannot be told to look
# past a .gitignore. rg and fd come from the Brewfile, but they are guarded
# anyway: a missing backend is silent rather than loud, because fzf treats a
# failed command as an empty result set and simply shows nothing.
#
# --no-ignore is deliberate: the point is to find files git is hiding, which is
# also why .git and node_modules have to be excluded by hand.
#
# Exported, not just set: the key bindings read the shell variable, but a bare
# `fzf` in a pipeline is a subprocess and only sees the environment.
if (( $+commands[rg] )); then
  export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules}/*"'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# Alt-C completes directories, which rg cannot list.
if (( $+commands[fd] )); then
  export FZF_ALT_C_COMMAND='fd --type d --no-ignore --hidden --follow --exclude .git --exclude node_modules'
fi

# Alt-C never arrives as Alt here. Neither terminal profile turns Option into
# Meta, because that would take away the characters Option types: # and € on a
# British or Irish keyboard, for a start. So Option-C sends a c-cedilla, and
# that is what gets bound, beside fzf's own binding rather than instead of it.
#
# Spelled as its two UTF-8 bytes: the line editor matches keys by byte, so this
# binds the same thing whatever the locale was when this file was read.
#
# Guarded on the widget, which fzf leaves out when FZF_ALT_C_COMMAND is empty.
if (( $+widgets[fzf-cd-widget] )); then
  bindkey -M emacs $'\xc3\xa7' fzf-cd-widget
  bindkey -M vicmd $'\xc3\xa7' fzf-cd-widget
  bindkey -M viins $'\xc3\xa7' fzf-cd-widget
fi
