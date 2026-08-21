#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

setup() {
  FAKE_HOME="$(mktemp -d)"
  guard_home "$FAKE_HOME"
}

teardown() {
  if [ -n "${FAKE_HOME:-}" ] && guard_home "$FAKE_HOME"; then
    rm -rf "$FAKE_HOME"
  fi
  return 0
}

run_setup() {
  ( cd "$REPO" && HOME="$FAKE_HOME" ./script/setup ) >/dev/null 2>&1
}

# Normalised snapshot of the home directory: name plus symlink target.
snapshot() {
  local f
  for f in "$FAKE_HOME"/.* "$FAKE_HOME"/*; do
    [ -e "$f" ] || continue
    case "${f##*/}" in .|..) continue ;; esac
    if [ -L "$f" ]; then echo "${f##*/} -> $(readlink "$f")"
    elif [ -d "$f" ]; then echo "${f##*/} (dir)"
    else echo "${f##*/} (file)"; fi
  done | sort
}

@test "never creates the four externally managed shell files" {
  run_setup
  local f
  for f in .profile .bashrc .zprofile .zshrc; do
    [ ! -e "$FAKE_HOME/$f" ] || { echo "setup created $f"; return 1; }
  done
}

@test "leaves pre-existing managed shell files untouched" {
  local f
  for f in .profile .bashrc .zprofile .zshrc; do
    echo "MANAGED CONTENT $f" > "$FAKE_HOME/$f"
  done
  run_setup
  for f in .profile .bashrc .zprofile .zshrc; do
    [ "$(cat "$FAKE_HOME/$f")" = "MANAGED CONTENT $f" ] \
      || { echo "setup modified $f"; return 1; }
  done
}

@test "links .zshenv into the repo" {
  run_setup
  [ -L "$FAKE_HOME/.zshenv" ]
  [ "$FAKE_HOME/.zshenv" -ef "$REPO/config/zsh/.zshenv" ]
}

@test "backs up a real .zshenv instead of clobbering it" {
  echo "PRE-EXISTING" > "$FAKE_HOME/.zshenv"
  run_setup
  [ -L "$FAKE_HOME/.zshenv" ]
  run cat "$FAKE_HOME"/.zshenv.bak.*
  [ "$output" = "PRE-EXISTING" ]
}

@test "is idempotent" {
  run_setup
  local first; first="$(snapshot)"
  run_setup
  local second; second="$(snapshot)"
  [ "$first" = "$second" ] || { diff <(echo "$first") <(echo "$second"); return 1; }
}

@test "does not replace an already-correct .config symlink" {
  run_setup
  local before; before="$(stat -f %i "$FAKE_HOME/.config")"
  # a file only reachable through the link; a blind rm -r would take it out
  date > "$REPO/config/.setup-canary"
  run_setup
  [ -e "$FAKE_HOME/.config/.setup-canary" ]
  rm -f "$REPO/config/.setup-canary"
  [ "$(stat -f %i "$FAKE_HOME/.config")" = "$before" ]
}

@test "does not link the repo's own scaffolding into home" {
  run_setup
  local f
  for f in .test .Makefile .script .README.md .LICENSE.md; do
    [ ! -e "$FAKE_HOME/$f" ] || { echo "setup linked $f"; return 1; }
  done
}

@test "creates an ssh config-local for machine-specific overrides" {
  run_setup
  [ -f "$FAKE_HOME/.ssh/config-local" ]
}

@test "backs up a pre-existing directory instead of deleting it" {
  # Any machine that has been used already has files under ~/.config and ~/.ssh.
  mkdir -p "$FAKE_HOME/.config/some-other-tool"
  echo "keep me" > "$FAKE_HOME/.config/some-other-tool/state"
  run_setup
  [ -L "$FAKE_HOME/.config" ]
  [ "$FAKE_HOME/.config" -ef "$REPO/config" ]
  local rescued
  rescued="$(cat "$FAKE_HOME"/.config.bak.*/some-other-tool/state 2>/dev/null)"
  [ "$rescued" = "keep me" ] || { echo "pre-existing content was destroyed"; return 1; }
}
