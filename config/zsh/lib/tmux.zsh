#!/usr/bin/env zsh

zinit snippet PZTM::tmux

alias tmux="tmux -f ${XDG_CONFIG_HOME}/tmux/tmux.conf"

# Session autostart lives at the top of .zshrc: it has to run before the rest of
# the interactive setup to be worth anything.
