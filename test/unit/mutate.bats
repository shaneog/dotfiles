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
|@test "in no hurry" { [ -z "${DOTFILES_TEST_PATIENCE:-}" ]; }
|# bats test_tags=timing
|@test "quick enough" { grep -q green "$BATS_TEST_DIRNAME/../settings"; }
|# Each of a pair, once broken, says it is running and looks for the other.
|meet() {
|  local tries=0
|  touch "$MEET/$1"
|  until [ -e "$MEET/$2" ] || [ "$((tries += 1))" -gt 30 ]; do sleep 0.1; done
|  [ ! -e "$MEET/$2" ] || touch "$MEET/met"
|  rm -f "$MEET/$1"
|}
|@test "first of a pair" {
|  grep -q green "$BATS_TEST_DIRNAME/../settings" || { meet first second; false; }
|}
|@test "second of a pair" {
|  grep -q green "$BATS_TEST_DIRNAME/../settings" || { meet second first; false; }
|}
|@test "the size, after a moment" { sleep 1; grep -q small "$BATS_TEST_DIRNAME/../settings"; }
|@test "the colour, after a moment" { sleep 1; grep -q green "$BATS_TEST_DIRNAME/../settings"; }
BATS
  git -C "$WORK" init -q
  export MEET="$BATS_TEST_TMPDIR/meet"
  mkdir -p "$MEET"
}

# The manifest: a row for every three arguments, which are what to break, the
# test file, and the test that must notice.
manifest() {  # sed expression, test file, test filter, ...
  : > "$WORK/test/mutations.tsv"
  while [ "$#" -gt 0 ]; do
    printf 'settings\t%s\t%s\t%s\twhat "%s" breaks\n' "$1" "$2" "$3" "$1" \
      >> "$WORK/test/mutations.tsv"
    shift 3
  done
  git -C "$WORK" add -A
  git -C "$WORK" -c user.name=tester -c user.email=tester@example.com \
    -c commit.gpgsign=false commit -q -m "rows to check"
}

# One row, breaking the colour, checked by the test named.
row() {  # test filter
  manifest 's|green|blue|' test/sample.bats "$1"
}

# The platform is whatever the stand-in uname says, so both answers are
# checked wherever this runs. The patience is taken out of the environment:
# script/mutate runs this file for its own rows, and hands it down.
mutate() {  # what uname reports
  printf '#!/bin/sh\necho %s\n' "$1" > "$STUBS/uname"
  chmod +x "$STUBS/uname"
  PATH="$STUBS:$PATH" _timeout 120 env -u DOTFILES_TEST_PATIENCE bash "$WORK/script/mutate"
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
  # With what the test said, which is all a red run in CI leaves to go on.
  assert_contains "$output" "grep -q red"
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

@test "mutate: a row is judged by its own test, not by another row's in the same file" {
  # The tests of one file are run together with nothing broken, once, and each
  # row then reads its own out of that.
  manifest 's|green|blue|' test/sample.bats "colour is green" \
           's|green|blue|' test/sample.bats "colour is red" \
           's|green|blue|' test/sample.bats "this machine lacks"
  run mutate Darwin
  [ "$status" -ne 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "1 caught, 1 missed"
  assert_contains "$output" "1 NOT CHECKED on this machine"
}

@test "mutate: rows are run side by side, as many as MUTATE_JOBS says" {
  # Each test of the pair, once the colour is broken, waits for the other to be
  # running. One after the other, neither ever sees it.
  manifest 's|green|blue|' test/sample.bats "first of a pair" \
           's|green|blue|' test/sample.bats "second of a pair"
  export MUTATE_JOBS=2
  run mutate Darwin
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "2 caught, 0 missed"
  [ -e "$MEET/met" ] || { echo "the two rows never ran at the same time"; return 1; }
}

@test "mutate: a row never sees what the row beside it broke" {
  # Two rows for one file, each checked by a test that only the other row's
  # breakage would fail. Run in one tree at once, at least one is "caught".
  printf 'colour = green\nsize = small\n' > "$WORK/settings"
  manifest 's|green|blue|' test/sample.bats "the size, after a moment" \
           's|small|big|'  test/sample.bats "the colour, after a moment"
  export MUTATE_JOBS=2
  run mutate Darwin
  refute_contains "$output" "BROKEN"
  assert_contains "$output" "0 caught, 2 missed"
}

@test "mutate: only the run after the mutation is told to hurry" {
  # A test that waits for a shell gives up sooner once the row has been broken.
  # Before that, it is the test as it is written.
  row "in no hurry"
  run mutate Darwin
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "1 caught, 0 missed"
}

@test "mutate: a test that measures time is run after the others, with nothing beside it" {
  # The test says so with a tag. Next to busy workers it would be slow whatever
  # the row did.
  manifest 's|green|blue|' test/sample.bats "quick enough" \
           's|green|red|'  test/sample.bats "colour is green"
  export MUTATE_JOBS=1
  run mutate Darwin
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "2 caught, 0 missed"
  local last; last="$(printf '%s\n' "$output" | grep '^  ok ' | tail -n 1)"
  assert_contains "$last" 's|green|blue|' "the last row to finish"
}
