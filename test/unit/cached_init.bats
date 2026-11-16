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

@test "regenerates when the command now leads to another binary, even an older one" {
  # Regression: only the binary's date was compared. Homebrew stamps a binary
  # with the date of the upstream source, so a version installed today can be
  # days older than the cache the last version wrote, and the cache stayed.
  local cellar="$BATS_TEST_TMPDIR/cellar" v
  for v in 1.0 2.0; do
    mkdir -p "$cellar/$v"
    printf '#!/bin/sh\necho called >> "$LOG"\necho "FAKETOOL_VERSION=%s"\n' "$v" > "$cellar/$v/faketool"
    chmod +x "$cellar/$v/faketool"
    touch -t 202001010000 "$cellar/$v/faketool"
  done
  ln -sf "$cellar/1.0/faketool" "$STUBS/faketool"
  call >/dev/null
  grep -q "FAKETOOL_VERSION=1.0" "$CACHE"
  # The upgrade: the same command, a new directory, a binary older than the cache.
  ln -sf "$cellar/2.0/faketool" "$STUBS/faketool"
  call >/dev/null; call >/dev/null
  grep -q "FAKETOOL_VERSION=2.0" "$CACHE" || { cat "$CACHE"; return 1; }
  assert_equal "$(wc -l < "$LOG" | tr -d ' ')" "2" "times the tool was run"
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
