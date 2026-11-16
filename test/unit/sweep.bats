#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# script/sweep edits tracked files in place and takes minutes, so what is tested
# here is the part that decides what it will not do again: the results file a
# run resumes from. A copy of the script sweeps a two-line config in a
# repository of its own, with a stand-in bats that fails every time, so each
# line is recorded as noticed without a real test running.

setup() {
  WORK="$BATS_TEST_TMPDIR/repo"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  OUT="$BATS_TEST_TMPDIR/sweep.tsv"
  SAMPLE="config/zsh/lib/sample.zsh"
  mkdir -p "$WORK/script" "$WORK/config/zsh/lib" "$STUBS"
  cp "$REPO/script/sweep" "$WORK/script/sweep"
  printf 'alias one=1\nalias two=2\n' > "$WORK/$SAMPLE"
  printf '#!/bin/sh\nexit 1\n' > "$STUBS/bats"
  chmod +x "$STUBS/bats"
  git -C "$WORK" init -q
  commit "a config to sweep"
}

commit() {
  git -C "$WORK" add -A
  git -C "$WORK" -c user.name=tester -c user.email=tester@example.com \
    -c commit.gpgsign=false commit -q -m "$1"
}

sweep() {
  PATH="$STUBS:$PATH" _timeout 120 bash "$WORK/script/sweep" --out "$OUT" "$SAMPLE"
}

@test "sweep: the line is commented out while the tests run" {
  # The stand-in bats fails whatever it finds, so the other tests here pass
  # when nothing was edited at all. This one keeps what the tests were shown.
  # BSD and GNU sed disagree about how an in-place edit is spelled, and the
  # wrong spelling edits nothing.
  printf '#!/bin/sh\ncat "%s" >> "%s"\nexit 1\n' "$WORK/$SAMPLE" "$BATS_TEST_TMPDIR/seen" > "$STUBS/bats"
  run sweep
  assert_contains "$output" "2 swept: 2 noticed"
  assert_equal "$(tr '\n' '/' < "$BATS_TEST_TMPDIR/seen")" \
    "# alias one=1/alias two=2/alias one=1/# alias two=2/" "what the tests saw, a line at a time"
  assert_equal "$(tr '\n' '/' < "$WORK/$SAMPLE")" "alias one=1/alias two=2/" "the file afterwards"
}

@test "sweep: a second run repeats nothing" {
  run sweep
  assert_contains "$output" "2 swept: 2 noticed"
  run sweep
  assert_contains "$output" "0 swept"
  assert_equal "$(grep -c '' "$OUT")" "2" "the number of recorded results"
}

@test "sweep: a line that has moved is swept again" {
  # Regression: results were resumed by line number alone. A line added at the
  # top gave every number below it to a different line, so the new line was
  # skipped as already swept and the old verdicts stayed against the wrong text.
  run sweep
  assert_contains "$output" "2 swept"

  printf 'alias zero=0\nalias one=1\nalias two=2\n' > "$WORK/$SAMPLE"
  commit "a line above the others"
  run sweep
  assert_contains "$output" "3 swept"

  local n line recorded
  for n in 1 2 3; do
    line="$(sed -n "${n}p" "$WORK/$SAMPLE")"
    recorded="$(awk -F'\t' -v n="$n" '$2 == n { print $4 }' "$OUT")"
    assert_equal "$recorded" "$line" "the result recorded for line $n"
  done
}

@test "sweep: a line that has not changed keeps its result" {
  run sweep
  # Appended, so the two lines above keep their numbers and their text.
  printf 'alias three=3\n' >> "$WORK/$SAMPLE"
  commit "a line below the others"
  run sweep
  assert_contains "$output" "1 swept"
  assert_equal "$(grep -c '' "$OUT")" "3" "the number of recorded results"
}
