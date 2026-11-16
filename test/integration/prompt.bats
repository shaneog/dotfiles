#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# config/starship.toml had no test of any kind: nothing asserted the prompt
# rendered at all, let alone that this config's character module was in effect.
# A broken prompt is loud when you notice it and silent in CI.

setup() {
  command -v starship >/dev/null 2>&1 || skip "starship is not installed"
  PROMPT_DIR="$BATS_TEST_TMPDIR/somedir"
  mkdir -p "$PROMPT_DIR"
}

prompt() {  # exit status to render for
  ( cd "$PROMPT_DIR" && STARSHIP_CONFIG="$REPO/config/starship.toml" \
      _timeout 30 starship prompt --status="$1" 2>&1 )
}

@test "prompt: renders, and names the directory it is in" {
  local out; out="$(prompt 0)"
  [ -n "$out" ] || { echo "starship rendered nothing"; return 1; }
  assert_contains "$out" "somedir" "the rendered prompt"
}

@test "prompt: the character module reflects the last exit status" {
  # Same glyph either way in this config, so the colour is the whole signal:
  # green on success, red on failure. Asserting the symbol alone would pass
  # with the error_symbol line deleted.
  local ok_prompt fail_prompt
  ok_prompt="$(prompt 0)"
  fail_prompt="$(prompt 1)"
  assert_contains "$ok_prompt" $'\033[32m' "the success prompt"
  assert_contains "$fail_prompt" $'\033[31m' "the failure prompt"
  refute_contains "$ok_prompt" $'\033[31m' "the success prompt"
}

@test "prompt: no leading blank line" {
  # add_newline = false. Easy to lose in a config merge and mildly maddening.
  local out; out="$(prompt 0)"
  case "$out" in
    $'\n'*) echo "the prompt starts with a newline"; return 1 ;;
  esac
}

@test "prompt: a rebase in progress is written in a colour the profile can show" {
  # Gotham gives slots 0, 8, 10 and 12 to shades of the background, so
  # "bright-black", the usual choice for a quiet marker, is one nobody can read.
  local git=(env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    git -C "$PROMPT_DIR" -c user.name=t -c user.email=t@example.invalid
    -c commit.gpgsign=false -c init.defaultBranch=main)
  "${git[@]}" init -q
  echo one > "$PROMPT_DIR/f" && "${git[@]}" add f && "${git[@]}" commit -qm one
  "${git[@]}" checkout -qb other
  echo two > "$PROMPT_DIR/f" && "${git[@]}" commit -qam two
  "${git[@]}" checkout -q main
  echo three > "$PROMPT_DIR/f" && "${git[@]}" commit -qam three
  # The conflict is the point: it is what leaves the rebase unfinished.
  "${git[@]}" rebase -q other >/dev/null 2>&1 || true

  local out before sgr
  out="$(prompt 0)"
  assert_contains "$out" "REBASING" "the rendered prompt"
  # The colour is whatever was set last before the word.
  before="${out%%REBASING*}"
  sgr="${before##*$'\033['}"
  sgr="${sgr%%m*}"
  case "$sgr" in
    30|90|92|94|*"38;5;0"|*"38;5;8"|*"38;5;10"|*"38;5;12"|"")
      echo "the rebase marker is written with SGR '$sgr'"; return 1 ;;
  esac
}
