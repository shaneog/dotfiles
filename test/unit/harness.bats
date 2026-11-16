#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# The harness itself.

@test "harness: guard_home refuses anything outside a temp directory" {
  run guard_home "$REAL_HOME"
  [ "$status" -ne 0 ] || { echo "guard_home accepted the real home"; return 1; }
  run guard_home "/"
  [ "$status" -ne 0 ] || { echo "guard_home accepted /"; return 1; }
}

@test "harness: a wait on a typed-into shell gives up when a mutated run's patience does" {
  # script/mutate breaks what such a test is waiting for, so every one of its
  # rows would otherwise sit out the whole wait.
  cat > "$BATS_TEST_TMPDIR/waits" <<'ZSH'
zmodload zsh/zpty
zpty -b shell cat
source $REPO/test/helpers/typing.zsh
wait_for /nonexistent/never-written 100
print "gave up: $?"
zpty -d shell
ZSH
  SECONDS=0
  DOTFILES_TEST_PATIENCE=5 run _timeout 60 "$ZSH_BIN" -f "$BATS_TEST_TMPDIR/waits"
  assert_contains "$output" "gave up: 1"
  [ "$SECONDS" -lt 6 ] || { echo "it waited ${SECONDS}s, where the test allowed ten and the run half of one"; return 1; }
}
