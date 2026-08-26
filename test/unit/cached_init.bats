bats_require_minimum_version 1.5.0

load '../helpers/common'

setup() {
  FAKE_HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$FAKE_HOME/.cache"
  LOG="$BATS_TEST_TMPDIR/calls.log"; : > "$LOG"
  STUBS="$(stub_dir)"
  stub_cmd faketool <<'STUB'
#!/bin/sh
echo "called" >> "$LOG"
echo "FAKETOOL_INIT=1"
STUB
  CACHE="$FAKE_HOME/.cache/zsh/init/faketool.zsh"
}

# Run cached_init in a bare shell and report $? plus $REPLY.
call() {
  env -i HOME="$FAKE_HOME" PATH="$STUBS:/usr/bin:/bin" LOG="$LOG" \
      XDG_CACHE_HOME="$FAKE_HOME/.cache" "$@" \
      "$ZSH_BIN" -fc "fpath=($REPO/config/zsh/autoload \$fpath)
                      autoload -Uz cached_init
                      cached_init faketool faketool init zsh
                      print -r -- \"status=\$? reply=\$REPLY\""
}

@test "generates the cache and reports its path" {
  run call
  assert_equal "$output" "status=0 reply=$CACHE"
  [ -s "$CACHE" ]
  grep -q "FAKETOOL_INIT=1" "$CACHE"
}

@test "reuses the cache instead of shelling out again" {
  call >/dev/null; call >/dev/null; call >/dev/null
  [ "$(wc -l < "$LOG" | tr -d ' ')" -eq 1 ]
}

@test "regenerates when the tool is newer than the cache" {
  call >/dev/null
  touch -t 202001010000 "$CACHE"       # cache older than the binary
  call >/dev/null
  [ "$(wc -l < "$LOG" | tr -d ' ')" -eq 2 ]
}

@test "reports failure and caches nothing when the tool is absent" {
  run env -i HOME="$FAKE_HOME" PATH="/usr/bin:/bin" \
      XDG_CACHE_HOME="$FAKE_HOME/.cache" \
      "$ZSH_BIN" -fc "fpath=($REPO/config/zsh/autoload \$fpath)
                      autoload -Uz cached_init
                      cached_init nope nope init zsh
                      print -r -- \"status=\$? reply=\$REPLY\""
  assert_equal "$output" "status=1 reply="
}

@test "leaves no partial cache behind when generation fails" {
  stub_cmd faketool <<'STUB'
#!/bin/sh
echo "partial output"
exit 1
STUB
  run call
  echo "$output" | grep -q "status=1"
  [ ! -e "$CACHE" ]
  [ -z "$(find "$FAKE_HOME/.cache/zsh/init" -name 'faketool.zsh.*' 2>/dev/null)" ]
}

@test "reports failure when the tool succeeds but writes nothing" {
  # An empty init script is worse than none: it is cached, sourced, and the tool
  # silently does not work. Exit status alone does not catch this.
  stub_cmd faketool <<'STUB'
#!/bin/sh
echo "called" >> "$LOG"
exit 0
STUB
  run call
  echo "$output" | grep -q "status=1" || { echo "$output"; return 1; }
  [ ! -e "$CACHE" ] || { echo "an empty init script was cached"; return 1; }
}
