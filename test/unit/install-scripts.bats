#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# script/bootstrap and script/remove only ever run for real on a new machine or
# a disposable runner, and the parts tested here are the ones a runner cannot
# reach: it has passwordless sudo, so the askpass helper is never written, it
# always has a network, and it has neither Xcode nor anyone else's symlinks.
#
# Two ways in. Small helpers are lifted out of the script by name and called
# directly, so nothing else in the script runs. Whole-script runs get a PATH of
# stubs and a disposable $HOME, and sudo is a stub that records its arguments
# and runs nothing: these scripts hand it `rm -rf` and `chsh`.

setup() {
  IHOME="$BATS_TEST_TMPDIR/home"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  LOG="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$IHOME" "$STUBS"
  guard_home "$IHOME"
  : > "$LOG"

  printf '#!/bin/sh\nprintf "sudo %%s\\n" "$*" >> "$CALL_LOG"\n' > "$STUBS/sudo"
  printf '#!/bin/sh\nexit 0\n' > "$STUBS/caffeinate"
  printf '#!/bin/sh\necho "staff admin"\n' > "$STUBS/groups"
  # Present, so bootstrap never reaches for Homebrew's installer; and curl
  # refuses, so nothing could be fetched even if it did.
  printf '#!/bin/sh\nexit 0\n' > "$STUBS/brew"
  printf '#!/bin/sh\nexit 1\n' > "$STUBS/curl"
  printf '#!/bin/sh\necho "UserShell: /bin/zsh"\n' > "$STUBS/dscl"
  chmod +x "$STUBS"/*
}

# Define one function from a script in this shell, without running the script.
load_fn() {  # script, function
  local body
  body="$(sed -n "/^$2() {/,/^}/p" "$REPO/script/$1")"
  [ -n "$body" ] || { echo "no function $2 in script/$1"; return 1; }
  eval "$body"
}

# A whole script, as an admin user who is not root, seeing only the stubs and
# the base system.
run_script() {  # script, args...
  local script="$1"; shift
  local s
  for s in sudo brew curl; do
    [ -x "$STUBS/$s" ] || { echo "refusing to run $script without a $s stub"; return 1; }
  done
  _timeout 60 env -i HOME="$IHOME" USER=tester PATH="$STUBS:/usr/bin:/bin" \
    CALL_LOG="$LOG" ${DOTFILES_URL:+DOTFILES_URL="$DOTFILES_URL"} \
    bash "$REPO/script/$script" "$@"
}

@test "the askpass helper hands back the password exactly as it was typed" {
  # Regression: the helper was written with the password pasted between double
  # quotes, so `pa$$word` came back as `pa` followed by a process id, and a
  # password containing backticks ran what was between them.
  local script helper pw
  for script in bootstrap remove; do
    load_fn "$script" write_askpass
    helper="$BATS_TEST_TMPDIR/askpass-$script"
    while IFS= read -r pw; do
      write_askpass "$helper" "$pw"
      chmod 700 "$helper"
      run "$helper"
      [ "$status" -eq 0 ]
      assert_equal "$output" "$pw" "what script/$script's helper printed"
    done <<'PASSWORDS'
correct horse battery
pa$$word
he said "hi"
back\slash and 'quotes'
tick`touch "$HOME/expanded"`mark
$(touch "$HOME/expanded")
-n leading dash
  two  spaces
pässwörd
PASSWORDS
    [ ! -e "$HOME/expanded" ] || { echo "the helper ran part of a password"; return 1; }
  done
}

@test "the password beside the askpass helper is readable only by its owner" {
  local script helper
  for script in bootstrap remove; do
    load_fn "$script" write_askpass
    helper="$BATS_TEST_TMPDIR/askpass-$script"
    write_askpass "$helper" "secret"
    assert_equal "$(ls -l "$helper.secret" | cut -c1-10)" "-rw-------" \
      "the mode of script/$script's password file"
  done
}

@test "bootstrap stops when the dotfiles cannot be fetched" {
  # Regression: an unreachable URL skipped the clone without a word, and the
  # run went on to finish with "Your system is now bootstrapped!".
  DOTFILES_URL="$BATS_TEST_TMPDIR/no-such-repo" run run_script bootstrap
  [ "$status" -ne 0 ]
  assert_contains "$output" "Cannot reach $BATS_TEST_TMPDIR/no-such-repo"
  refute_contains "$output" "now bootstrapped"
  [ ! -e "$IHOME/.dotfiles" ]
}

@test "remove takes the links into the clone and leaves other dangling links alone" {
  mkdir -p "$IHOME/.dotfiles/config/zsh" "$IHOME/elsewhere"
  : > "$IHOME/.dotfiles/config/zsh/.zshenv"
  ln -s "$IHOME/.dotfiles/config" "$IHOME/.config"
  # Through .config rather than straight into the clone, as script/setup makes it.
  ln -s "$IHOME/.config/zsh/.zshenv" "$IHOME/.zshenv"
  ln -s "$IHOME/elsewhere" "$IHOME/.kept"
  # Already dangling before anything is removed: a share that is not mounted.
  ln -s "$BATS_TEST_TMPDIR/not-mounted/share" "$IHOME/nas"

  run run_script remove <<< "y"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }

  [ ! -e "$IHOME/.dotfiles" ]
  [ ! -L "$IHOME/.config" ] || { echo ".config survived as a dangling link"; return 1; }
  [ ! -L "$IHOME/.zshenv" ] || { echo ".zshenv survived as a dangling link"; return 1; }
  [ -L "$IHOME/.kept" ]     || { echo "a link to somewhere else was removed"; return 1; }
  [ -L "$IHOME/nas" ]       || { echo "someone else's dangling link was removed"; return 1; }
}

@test "remove only ever names the Command Line Tools for deletion" {
  load_fn remove command_line_tools_dir

  printf '#!/bin/sh\necho /Applications/Xcode.app/Contents/Developer\n' > "$STUBS/xcode-select"
  chmod +x "$STUBS/xcode-select"
  PATH="$STUBS:$PATH" run command_line_tools_dir
  [ "$status" -ne 0 ]
  [ -z "$output" ] || { echo "offered Xcode's own directory: $output"; return 1; }

  printf '#!/bin/sh\necho /Library/Developer/CommandLineTools\n' > "$STUBS/xcode-select"
  PATH="$STUBS:$PATH" run command_line_tools_dir
  [ "$status" -eq 0 ]
  assert_equal "$output" "/Library/Developer/CommandLineTools"

  # Nothing selected at all, which is how xcode-select answers on a machine
  # that has neither.
  printf '#!/bin/sh\necho "error: unable to get active developer directory" >&2\nexit 2\n' \
    > "$STUBS/xcode-select"
  PATH="$STUBS:$PATH" run command_line_tools_dir
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}
