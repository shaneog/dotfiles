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
