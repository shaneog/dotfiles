#!/usr/bin/env zsh

zinit snippet PZTM::tmux

alias tmux="tmux -f ${XDG_CONFIG_HOME}/tmux/tmux.conf"

# Automatically launch a tmux session, unless TMUX is already set or TERM_PROGRAM is set to vscode
if [[ -z "$TMUX" ]] && [[ "$TERM_PROGRAM" != "vscode" ]]; then
case $- in *i*)
      tmux_session="$(echo $USER | tr -d '.')"

      if tmux has-session -t "$tmux_session" 2>/dev/null; then
        # only attach if no other client connected
        if [ "$(tmux list-clients | wc -l)" -eq "0" ]; then
          tmux attach-session -t "$tmux_session"
        fi
      else
        tmux new-session -s "$tmux_session"
      fi
  esac
fi
