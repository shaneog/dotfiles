bats_require_minimum_version 1.5.0

load '../helpers/common'

setup() {
  FAKE_HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$FAKE_HOME/.cache"
  LOG="$BATS_TEST_TMPDIR/calls.log"; : > "$LOG"
  STUBS="$(stub_dir)"
  stub_cmd faketool <<'STUB'
#!/bin/sh
echo "called" >> "$LOG"
echo "#compdef faketool"
STUB
  CACHE="$FAKE_HOME/.cache/zsh/completions/_faketool"
}

call() {
  env -i HOME="$FAKE_HOME" PATH="$STUBS:/usr/bin:/bin" LOG="$LOG" \
      XDG_CACHE_HOME="$FAKE_HOME/.cache" "$@" \
      "$ZSH_BIN" -fc "fpath=($REPO/config/zsh/autoload \$fpath)
                      autoload -Uz cached_completion
                      cached_completion faketool faketool completion zsh
                      print -r -- \"status=\$? onfpath=\$(print -l \$fpath | grep -c 'zsh/completions')\""
}

@test "writes the completion where compinit will find it" {
  run call
  assert_equal "$output" "status=0 onfpath=1"
  grep -q "#compdef faketool" "$CACHE"
}

@test "does not run the tool again once cached" {
  call >/dev/null; call >/dev/null; call >/dev/null
  [ "$(wc -l < "$LOG" | tr -d ' ')" -eq 1 ]
}

@test "regenerates when the tool is newer than the cache" {
  call >/dev/null
  touch -t 202001010000 "$CACHE"
  call >/dev/null
  [ "$(wc -l < "$LOG" | tr -d ' ')" -eq 2 ]
}

@test "reports failure and leaves nothing behind when generation fails" {
  stub_cmd faketool <<'STUB'
#!/bin/sh
echo "partial"
exit 1
STUB
  run call
  echo "$output" | grep -q "status=1"
  [ ! -e "$CACHE" ]
  [ -z "$(find "$FAKE_HOME/.cache/zsh/completions" -name '_faketool.*' 2>/dev/null)" ]
}

@test "is a no-op when the tool is not installed" {
  run env -i HOME="$FAKE_HOME" PATH="/usr/bin:/bin" XDG_CACHE_HOME="$FAKE_HOME/.cache" \
    "$ZSH_BIN" -fc "fpath=($REPO/config/zsh/autoload \$fpath)
                    autoload -Uz cached_completion
                    cached_completion nope nope completion zsh
                    print -r -- \"status=\$?\""
  assert_equal "$output" "status=1"
}
