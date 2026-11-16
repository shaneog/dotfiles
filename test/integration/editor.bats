#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# lib/editor.zsh, typed into. A binding that exists is not a key that works, so
# most of these press the key in a real line editor and look at what the shell
# then ran.

setup() {
  EDITOR_HOME="$(make_home)"
}

teardown() {
  if [ -n "${EDITOR_HOME:-}" ] && guard_home "$EDITOR_HOME"; then
    rm -rf "$EDITOR_HOME"
  fi
  return 0
}

# Starts a login shell on a terminal of its own and types into it. The typing is
# zsh on stdin: `line` types a line, presses Return and waits for the prompt
# after it, `keys` types and does not. The shell is finished when it has written
# the file named in $1 in its home directory, and TYPED is then what that file
# holds.
typed() {  # the file the shell is expected to write
  local driver="$BATS_TEST_TMPDIR/driver"
  {
    cat <<'OPEN'
zmodload zsh/zpty zsh/terminfo
home=$1 zsh=$2 expect=$3
# The terminal the shell is told it has, so that $terminfo here describes it.
TERM=xterm-256color
zpty -b shell env -i HOME=$home PATH=$PATH TERM=$TERM SHLVL=1 \
  USER=${USER:-tester} ZSH_NO_TMUX_AUTOSTART=1 ZSH_NO_ZCOMPILE=1 $zsh -li
# Left unread, the shell's output fills the terminal and stops it.
seen=
wait_for() {  # a file the shell writes, tenths of a second to allow
  local more tries=0
  until [[ -e $1 ]]; do
    zpty -r shell more 2>/dev/null && seen+=$more
    (( ++tries > $2 )) && return 1
    sleep 0.1
  done
}
keys() { zpty -w -n shell "$1" }
# Between two prompts the terminal reads the keys, not the line editor, and it
# keeps Control-R and Control-W for itself. So the shell says when it is
# editing a line, and nothing is typed at it before then.
line() {
  rm -f $home/editing
  keys "$1"$'\r'
  wait_for $home/editing ${2:-300} || { print -r -- "no prompt came back after: $1"; exit 1 }
}
look() {  # at whatever the shell has shown by now
  local more
  sleep 0.5
  while zpty -r shell more 2>/dev/null; do seen+=$more; done
}
line "_editing() { print > ${(q)home}/editing }; zle -N _editing; add-zle-hook-widget line-init _editing" 900
OPEN
    cat
    cat <<'CLOSE'
wait_for $home/$expect 300 || {
  print -r -- "the shell never wrote $expect. The end of what it showed:"
  print -r -- "${(V)seen[-400,-1]}"
  exit 1
}
zpty -d shell
CLOSE
  } > "$driver"
  run _timeout 180 "$ZSH_BIN" -f "$driver" "$EDITOR_HOME" "$ZSH_BIN" "$1"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  TYPED="$(cat "$EDITOR_HOME/$1")"
}

@test "a shell started from one of ours still edits with the emacs keys" {
  # zsh picks the vi keymap by itself when EDITOR contains "vi" as it starts,
  # and common.zsh exports EDITOR=nvim. So the shell to ask is not the first
  # one, which started without it, but one started from it: a tmux pane.
  run run_login_shell "$EDITOR_HOME" "$ZSH_BIN -ic 'print -r -- \"\$EDITOR \$(bindkey -lL main)\"'"
  assert_contains "$output" "nvim bindkey -A emacs main"
}

@test "every key the editor binds reaches its widget" {
  # The whole table, so that a line lost from it is noticed. The sequences are
  # what TERM=xterm-256color describes, which is what run_login_shell sets.
  run run_login_shell "$EDITOR_HOME" 'bindkey -M emacs'
  local key widget
  while read -r key widget; do
    printf '%s\n' "$output" | grep -qxF "\"$key\" $widget" \
      || { echo "$key is not bound to $widget:"; printf '%s\n' "$output" | grep -F "\"$key\""; return 1; }
  done <<'KEYS'
^[b emacs-backward-word
^[B emacs-backward-word
^[[1;5D emacs-backward-word
^[[5D emacs-backward-word
^[^[[D emacs-backward-word
^[Od emacs-backward-word
^[^[OD emacs-backward-word
^[f emacs-forward-word
^[F emacs-forward-word
^[[1;5C emacs-forward-word
^[[5C emacs-forward-word
^[^[[C emacs-forward-word
^[Oc emacs-forward-word
^[^[OC emacs-forward-word
^[OH beginning-of-line
^[OF end-of-line
^[[2~ overwrite-mode
^[[3~ delete-char
^? backward-delete-char
^[OD backward-char
^[OC forward-char
^[k backward-kill-line
^[K backward-kill-line
^[_ redo
^@ _dotfiles_expand_aliases
^X^E edit-command-line
^[e expand-cmd-path
^[E expand-cmd-path
^[m copy-prev-shell-word
^[M copy-prev-shell-word
^Q push-line-or-edit
^[q push-line-or-edit
^[Q push-line-or-edit
^[[Z reverse-menu-complete
^X^B vi-find-prev-char
^X^] vi-match-bracket
^S history-incremental-pattern-search-forward
KEYS
}

@test "a third dot becomes the next directory up" {
  typed dots <<'TYPE'
line "print -r -- .... > ${(q)home}/dots"
TYPE
  assert_equal "$TYPED" "../../.." "what four dots typed"
}

@test "a dot typed into a history search is a dot" {
  # The search is for the line that wrote a file called a.b, and running what
  # it finds writes the file again. A dot that became the widget above would
  # end the search at "a", on the line that removes the file.
  typed a.b <<'TYPE'
line "bindkey -M emacs '^R' history-incremental-pattern-search-backward"
line "print -r -- one > ${(q)home}/a.b"
line "rm ${(q)home}/a.?"
keys $'\C-r'
keys "a.b"
line ""
TYPE
  assert_equal "$TYPED" "one" "what the line the search found wrote"
}

@test "a URL typed at the prompt reaches the command whole" {
  # Unquoted, its ? is a glob that matches nothing and its & ends the command.
  typed url <<'TYPE'
line "print -r -- http://example.com/?a=1&b=2 > ${(q)home}/url"
TYPE
  assert_equal "$TYPED" "http://example.com/?a=1&b=2" "what the command was given"
}

@test "deleting a word stops at each part of a path" {
  typed word <<'TYPE'
keys "print -r -- /one/two/three"
keys $'\C-w'
line "four > ${(q)home}/word"
TYPE
  assert_equal "$TYPED" "/one/two/four" "what was left of the path"
}

@test "Esc-semicolon comments a line out and back in" {
  typed comment <<'TYPE'
keys "#print -r -- back > ${(q)home}/comment"
keys $'\e;'
line ""
TYPE
  assert_equal "$TYPED" "back" "what the uncommented line ran"
}

@test "Control-X Control-S puts sudo in front of the line" {
  typed sudo <<'TYPE'
line "sudo() { print -r -- \"\$*\" > ${(q)home}/sudo }"
keys "print hello"
keys $'\C-x\C-s'
line ""
TYPE
  assert_equal "$TYPED" "print hello" "what sudo was asked to run"
}

@test "Control-space spells out the aliases on the line" {
  # Moved behind a print once it is spelled out: an alias still on the line
  # would be printed by name there, where it is no longer the command.
  typed expanded <<'TYPE'
line "alias sevenish='seven of them'"
keys "sevenish"
keys $'\C-@'
keys $'\C-a'
keys "print -r -- "
keys $'\C-e'
line "> ${(q)home}/expanded"
TYPE
  assert_equal "$TYPED" "seven of them" "the line after Control-space"
}

@test "Control-S searches forward instead of freezing the terminal" {
  # Two things have to hold: the terminal must pass the key on, and the line
  # editor must do something with it.
  typed flow <<'TYPE'
line "stty -a | grep -c -e '-ixon' > ${(q)home}/flow"
TYPE
  assert_equal "$TYPED" "1" "how many times stty reports flow control off"
}

@test "the terminal is in application mode while a line is edited" {
  # $terminfo gives the sequences keys send in application mode, and those are
  # what the arrow keys are bound by. In the other mode Up sends something no
  # binding matches.
  typed mode <<'TYPE'
on="$(echoti smkx)"
line "true"
look
if [[ -n $on && $seen == *"$on"* ]]; then print on; else print off; fi > $home/mode
TYPE
  assert_equal "$TYPED" "on" "application mode at the prompt"
}

@test "a line from history is suggested, and End takes it" {
  needs_plugin zsh-autosuggestions
  typed suggested <<'TYPE'
line "print -r -- taken-from-history > ${(q)home}/suggested"
line "rm ${(q)home}/suggested"
keys "print -r -- taken-f"
# The suggestion is fetched in the background.
sleep 1
keys $'\C-e'
line ""
TYPE
  assert_equal "$TYPED" "taken-from-history" "what the completed line wrote"
}

@test "Up searches history for what has been typed so far" {
  needs_plugin zsh-history-substring-search
  # The key as a terminal in application mode sends it, which is what
  # history.zsh binds. Plain Up would bring back the line before this one,
  # which removes the file.
  typed recalled <<'TYPE'
up="$(echoti kcuu1)"
line "true fir && print -r -- again > ${(q)home}/recalled"
line "rm ${(q)home}/recalled"
keys "true fir"
keys "$up"
line ""
TYPE
  assert_equal "$TYPED" "again" "what the recalled line wrote"
}
