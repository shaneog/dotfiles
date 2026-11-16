#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# script/mutate is what says the other assertions can fail, so its own verdicts
# have to be able to. A copy of the script runs in a repository of its own, with
# one line of config, a manifest written by each test, and real bats tests that
# read the config.

setup() {
  WORK="$BATS_TEST_TMPDIR/repo"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$WORK/script" "$WORK/test" "$STUBS"
  cp "$REPO/script/mutate" "$WORK/script/mutate"
  printf 'colour = green\n' > "$WORK/settings"
  # Each line starts with a bar, taken off again here: bats rewrites every line
  # of this file that starts with @test, inside a heredoc or not.
  sed 's/^|//' > "$WORK/test/sample.bats" <<'BATS'
|@test "the colour is green" { grep -q green "$BATS_TEST_DIRNAME/../settings"; }
|@test "the file is there" { [ -f "$BATS_TEST_DIRNAME/../settings" ]; }
|@test "the colour is red" { grep -q red "$BATS_TEST_DIRNAME/../settings"; }
|@test "a tool this machine lacks" { skip "not installed"; }
|# bats test_tags=macos
|@test "only on a mac" { grep -q green "$BATS_TEST_DIRNAME/../settings"; }
BATS
  git -C "$WORK" init -q
}

# One row, breaking the colour, checked by the test named.
row() {  # test filter
  printf 'settings\ts|green|blue|\ttest/sample.bats\t%s\tthe colour changes\n' "$1" \
    > "$WORK/test/mutations.tsv"
  git -C "$WORK" add -A
  git -C "$WORK" -c user.name=tester -c user.email=tester@example.com \
    -c commit.gpgsign=false commit -q -m "a row to check"
}

# The platform is whatever the stand-in uname says, so both answers are
# checked wherever this runs.
mutate() {  # what uname reports
  printf '#!/bin/sh\necho %s\n' "$1" > "$STUBS/uname"
  chmod +x "$STUBS/uname"
  PATH="$STUBS:$PATH" _timeout 120 bash "$WORK/script/mutate"
}

@test "mutate: a mutation the test notices is caught, and the file is put back" {
  # Also the only check that the edit is applied with this machine's sed: BSD
  # and GNU disagree about how an in-place edit is spelled.
  row "colour is green"
  run mutate Darwin
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "1 caught, 0 missed"
  assert_equal "$(cat "$WORK/settings")" "colour = green" "the file afterwards"
  assert_equal "$(git -C "$WORK" status --porcelain)" "" "what the run left behind"
}

@test "mutate: a mutation no test notices is a miss" {
  row "file is there"
  run mutate Darwin
  [ "$status" -ne 0 ] || { echo "a miss exited 0: $output"; return 1; }
  assert_contains "$output" "MISS"
  assert_contains "$output" "0 caught, 1 missed"
}

@test "mutate: a test that fails before anything is broken proves nothing" {
  # It fails after the mutation too, which is all that being caught used to mean.
  row "colour is red"
  run mutate Darwin
  [ "$status" -ne 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "fails before anything is broken"
  assert_contains "$output" "0 caught, 1 missed"
}

@test "mutate: a test that needs a Mac is not checked anywhere else, and says so" {
  row "only on a mac"
  run mutate Linux
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "NOT CHECKED, its test needs a Mac"
  assert_contains "$output" "0 caught, 0 missed"
  assert_contains "$output" "1 NOT CHECKED on this machine"
}

@test "mutate: on a Mac the same test is run, and catches it" {
  row "only on a mac"
  run mutate Darwin
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "1 caught, 0 missed"
  refute_contains "$output" "NOT CHECKED"
}

@test "mutate: a test this machine skips is not checked, rather than a miss" {
  row "this machine lacks"
  run mutate Darwin
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "NOT CHECKED, its test is skipped on this machine"
  assert_contains "$output" "0 caught, 0 missed"
}

@test "mutate: a filter that matches no test is broken, on a Mac or off one" {
  row "no such test"
  run mutate Darwin
  [ "$status" -ne 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "no test matches"
  run mutate Linux
  [ "$status" -ne 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "no test matches"
}
