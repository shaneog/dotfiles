#!/usr/bin/env zsh

# Window and tab titles: the folder while the prompt waits, the command while
# one runs. Cut down from prezto's terminal module:
# https://github.com/sorin-ionescu/prezto/blob/master/modules/terminal/init.zsh

[[ $TERM == (dumb|linux|*bsd*|eterm*) ]] && return

# Inside tmux the titles are tmux's: tmux.conf names each window after its
# folder and passes a title on to the terminal outside.
[[ -n $TMUX || -n $STY ]] && return

autoload -Uz add-zsh-hook

# Terminal.app names a tab after whatever is running without being asked. What
# it cannot know is the folder, which it shows in the title bar and opens a new
# tab in, so that is all it is told.
if [[ $TERM_PROGRAM == Apple_Terminal ]]; then
  _dotfiles_terminal_app_folder() {
    printf '\e]7;%s\a' "file://${HOST}${PWD// /%20}"
  }
  # Taken back when the command is one that leaves this shell behind: the
  # folder shown would go on being this one, whatever happened in there.
  _dotfiles_terminal_app_folder_clear() {
    [[ ${2[(w)1]:t} == (screen|tmux|dvtm|ssh|mosh) ]] && printf '\e]7;\a'
    return 0
  }
  add-zsh-hook precmd  _dotfiles_terminal_app_folder
  add-zsh-hook preexec _dotfiles_terminal_app_folder_clear
  return
fi

# OSC 1 names the tab and OSC 2 the window. (V) spells a control character out
# instead of sending it to the terminal as part of a title.
_dotfiles_title() {  # tab, window
  printf '\e]1;%s\a\e]2;%s\a' "${(V)1}" "${(V)2}"
}

# A tab is narrow, so it gets the end of a long path and the start of a long
# command.
_dotfiles_title_folder() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local MATCH MBEGIN MEND folder=${PWD/#$HOME/\~}
  _dotfiles_title "${folder/(#m)?(#c15,)/...${MATCH[-12,-1]}}" "$folder"
}

_dotfiles_title_command() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  # $2 is the command line on one line. Its first word that is not an
  # assignment, a flag, or the sudo or ssh in front of the real command.
  local MATCH MBEGIN MEND cmd=${${2[(wr)^(*=*|sudo|ssh|-*)]}:t}
  _dotfiles_title "${cmd/(#m)?(#c15,)/${MATCH[1,12]}...}" "$cmd"
}

add-zsh-hook precmd  _dotfiles_title_folder
add-zsh-hook preexec _dotfiles_title_command
