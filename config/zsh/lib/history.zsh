#!/usr/bin/env zsh

[ ! -d "${XDG_DATA_HOME}/zsh" ] && mkdir "${XDG_DATA_HOME}/zsh"

export HISTFILE=$XDG_DATA_HOME/zsh/zhistory
export HISTSIZE=50000
export SAVEHIST=100000

# History command configuration
setopt BANG_HIST                # Treat the '!' character specially during expansion.
setopt EXTENDED_HISTORY         # Write the history file in the ':start:elapsed;command' format.
setopt INC_APPEND_HISTORY       # write after each command
setopt SHARE_HISTORY            # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST   # Expire a duplicate event first when trimming history.
setopt HIST_IGNORE_DUPS         # Do not record an event that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS     # Delete an old recorded event if a new event is a duplicate.
setopt HIST_FIND_NO_DUPS        # Do not display a previously found event.
setopt HIST_IGNORE_SPACE        # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS        # Do not write a duplicate event to the history file.
setopt HIST_VERIFY              # Do not execute immediately upon history expansion.
setopt HIST_BEEP                # Beep when accessing non-existent history.
setopt HIST_REDUCE_BLANKS       # exclude blanks
setopt HIST_NO_STORE            # Do not add history and fc commands to the history
