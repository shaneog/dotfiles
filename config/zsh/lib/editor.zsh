#!/usr/bin/env zsh

# The line editor: what the keys do at the prompt. The bindings are the emacs
# half of prezto's editor module, so they are the ones the hands already know:
# https://github.com/sorin-ionescu/prezto/blob/master/modules/editor/init.zsh
#
# This file has to sort before fzf.zsh and history.zsh. Both bind keys of their
# own, and the reset below would take those away.

[[ $TERM == dumb ]] && return

# What counts as part of a word when moving or deleting by one. zsh's default
# without / and =, so a word ends at each part of a path and at either side of
# an assignment.
WORDCHARS='*?_-.[]~&;!#$%^(){}<>'

# A URL is quoted as it is typed or pasted. Left alone, its ? is a glob that
# matches nothing and its & puts half the command in the background.
autoload -Uz bracketed-paste-url-magic url-quote-magic
zle -N bracketed-paste bracketed-paste-url-magic
zle -N self-insert url-quote-magic

##
# Widgets
##

autoload -Uz edit-command-line
zle -N edit-command-line

# A third dot becomes /.. so that .... is ../../..
_dotfiles_expand_dots() {
  if [[ $LBUFFER == *.. ]]; then
    LBUFFER+='/..'
  else
    LBUFFER+='.'
  fi
}
zle -N _dotfiles_expand_dots

_dotfiles_prepend_sudo() {
  if [[ $BUFFER != su(do|)\ * ]]; then
    BUFFER="sudo $BUFFER"
    (( CURSOR += 5 ))
  fi
}
zle -N _dotfiles_prepend_sudo

# Every alias on the line, global ones too, replaced by what it stands for.
_dotfiles_expand_aliases() {
  zle _expand_alias
  zle expand-word
  zle magic-space
}
zle -N _dotfiles_expand_aliases

# Comment the line out, or back in. zsh's own pound-insert also accepts the
# line, which is no use for taking the # off again.
_dotfiles_toggle_comment() {
  if [[ $BUFFER == '#'* ]]; then
    # Before the buffer shrinks: zsh moves a cursor that is past the end, and
    # nothing else.
    (( CURSOR == $#BUFFER )) || (( CURSOR -= 1 ))
    BUFFER="${BUFFER:1}"
  else
    BUFFER="#$BUFFER"
    (( CURSOR += 1 ))
  fi
}
zle -N _dotfiles_toggle_comment

##
# Keys
##

# Every keymap back to zsh's defaults, then emacs as the one in use. A base
# layer may have bound keys of its own, and the bindings below should mean the
# same thing whatever is underneath.
#
# The -e is not a formality. zsh chooses the vi keymap by itself when EDITOR or
# VISUAL contains "vi" as the shell starts, which "nvim" does in every shell
# started from one that has read common.zsh: a tmux pane, for a start.
bindkey -d
bindkey -e

# $terminfo is what this terminal says each key sends. A key it does not
# describe is left unquoted below, so it expands to no argument at all and is
# skipped: binding an empty sequence is an error.
() {
  zmodload zsh/terminfo
  local key
  local -A sends=(
    home      "$terminfo[khome]"
    end       "$terminfo[kend]"
    insert    "$terminfo[kich1]"
    left      "$terminfo[kcub1]"
    right     "$terminfo[kcuf1]"
    shift-tab "$terminfo[kcbt]"
  )
  _dotfiles_bind() {  # widget, the sequences that reach it
    local widget=$1 key; shift
    for key in "$@"; do
      bindkey -M emacs -- "$key" $widget
    done
  }

  # By word: Esc-b and Esc-f, and Control or Option with the arrow keys, which
  # terminals send four different ways.
  _dotfiles_bind emacs-backward-word '\eB' '\eb' '\e[1;5D' '\e[5D' '\e\e[D' '\eOd' ${sends[left]:+"\e$sends[left]"}
  _dotfiles_bind emacs-forward-word  '\eF' '\ef' '\e[1;5C' '\e[5C' '\e\e[C' '\eOc' ${sends[right]:+"\e$sends[right]"}

  _dotfiles_bind beginning-of-line     $sends[home]
  _dotfiles_bind end-of-line           $sends[end]
  _dotfiles_bind overwrite-mode        $sends[insert]
  _dotfiles_bind delete-char           '\e[3~'
  _dotfiles_bind backward-delete-char  '^?'
  _dotfiles_bind backward-char         $sends[left]
  _dotfiles_bind forward-char          $sends[right]
  _dotfiles_bind backward-kill-line    '\eK' '\ek'
  _dotfiles_bind redo                  '\e_'

  # Space expands a history reference such as !! or !$ where it stands, so it
  # can be read before it is run.
  _dotfiles_bind magic-space ' '
  _dotfiles_bind _dotfiles_expand_dots '.'
  # ... but not while searching, where a dot is a dot.
  bindkey -M isearch . self-insert 2>/dev/null

  _dotfiles_bind _dotfiles_expand_aliases '^ '
  _dotfiles_bind _dotfiles_prepend_sudo   '^X^S'
  _dotfiles_bind _dotfiles_toggle_comment '\e;'
  _dotfiles_bind edit-command-line        '^X^E'
  _dotfiles_bind expand-cmd-path          '\eE' '\ee'
  _dotfiles_bind copy-prev-shell-word     '\eM' '\em'
  # Set the line aside, run something else, and get it back. Unlike push-line,
  # this takes the whole of a command that runs over several lines.
  _dotfiles_bind push-line-or-edit        '^Q' '\eQ' '\eq'
  _dotfiles_bind reverse-menu-complete    $sends[shift-tab]
  _dotfiles_bind vi-find-prev-char        '^X^B'
  _dotfiles_bind vi-match-bracket         '^X^]'

  # Searching history by pattern, so * and ? work. fzf.zsh takes Control-R when
  # fzf is installed; Control-S stays.
  _dotfiles_bind history-incremental-pattern-search-backward '^R'
  _dotfiles_bind history-incremental-pattern-search-forward  '^S'

  unfunction _dotfiles_bind
}

# Control-S and Control-Q reach the bindings above, instead of stopping and
# starting the terminal's output.
[[ -r ${TTY:-} && -w ${TTY:-} ]] && (( $+commands[stty] )) && stty -ixon <$TTY >$TTY

# $terminfo describes the keys as a terminal sends them in application mode,
# so the terminal is put into it for as long as a line is being edited. Without
# this the arrow keys send something else, and the bindings above and the
# history search on Up and Down in history.zsh never match.
if (( $+terminfo[smkx] && $+terminfo[rmkx] )); then
  autoload -Uz add-zle-hook-widget
  _dotfiles_application_mode_on()  { echoti smkx }
  _dotfiles_application_mode_off() { echoti rmkx }
  add-zle-hook-widget line-init   _dotfiles_application_mode_on
  add-zle-hook-widget line-finish _dotfiles_application_mode_off
fi
