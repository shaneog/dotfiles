#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# script/macos changes the machine, which is why it has only ever been exercised
# by the VM tier and the provision workflow -- both slow, both rare. These stub
# `defaults` and friends so the logic can be tested in a second: that --check
# writes nothing, that a correct setting is left alone, that nvram values go to
# nvram, that the first-run capture is written once and never overwritten, and
# that a rejected write is counted rather than swallowed.
#
# The stub records writes into a state file and answers reads from it, so an
# apply followed by a --check exercises the round trip through as_read -- the
# normalisation that decides whether a setting looks applied.

setup() {
  MHOME="$BATS_TEST_TMPDIR/home"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  STATE="$BATS_TEST_TMPDIR/state"
  LOG="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$MHOME" "$STUBS"
  : > "$STATE"
  : > "$LOG"

  cat > "$STUBS/defaults" <<'EOF'
#!/bin/sh
printf 'defaults %s\n' "$*" >> "$CALL_LOG"
case "$1" in
  read)
    # "domain key" -> value, from whatever a previous write recorded
    key="$2 $3"
    grep -F "$key=" "$STATE_FILE" 2>/dev/null | tail -1 | sed "s|^.*$key=||" | grep . || exit 1
    ;;
  write)
    domain="$2"; name="$3"; type="$4"; value="$5"
    case "$type" in
      -bool)  case "$value" in true|yes|1) stored=1 ;; *) stored=0 ;; esac ;;
      -array) stored="($value)" ;;
      *)      stored="$value" ;;
    esac
    [ "$name" = "$REJECT_KEY" ] && exit 1
    printf '%s %s=%s\n' "$domain" "$name" "$stored" >> "$STATE_FILE"
    ;;
  export) exit 0 ;;
esac
exit 0
EOF

  cat > "$STUBS/nvram" <<'EOF'
#!/bin/sh
printf 'nvram %s\n' "$*" >> "$CALL_LOG"
case "$1" in
  *=*) printf 'nvram %s=%s\n' "${1%%=*}" "${1#*=}" >> "$STATE_FILE" ;;
  *)   grep -F "nvram $1=" "$STATE_FILE" 2>/dev/null | tail -1 \
         | sed "s|^nvram $1=||" | awk '{print "'"$1"'\t" $0}' | grep . || exit 1 ;;
esac
exit 0
EOF

  for noop in killall open chsh; do
    printf '#!/bin/sh\nprintf "%s %%s\\n" "$*" >> "$CALL_LOG"\nexit 0\n' "$noop" > "$STUBS/$noop"
  done
  # dscl has to answer: the capture pipes it into awk and writes the result.
  printf '#!/bin/sh\nprintf "dscl %%s\\n" "$*" >> "$CALL_LOG"\necho "UserShell: /bin/zsh"\n' > "$STUBS/dscl"
  # sudo has to run what it is given, or the nvram branch silently does nothing.
  printf '#!/bin/sh\nprintf "sudo %%s\\n" "$*" >> "$CALL_LOG"\nexec "$@"\n' > "$STUBS/sudo"
  # Not a desktop session, so the Terminal profile import stays out of the way.
  printf '#!/bin/sh\necho Background\n' > "$STUBS/launchctl"
  chmod +x "$STUBS"/*
}

# _timeout first: it is a shell function, and env can only exec a binary.
macos() {
  _timeout 120 env -i HOME="$MHOME" PATH="$STUBS:/usr/bin:/bin" USER="${USER:-tester}" \
    XDG_DATA_HOME="$MHOME/.local/share" \
    CALL_LOG="$LOG" STATE_FILE="$STATE" REJECT_KEY="${REJECT_KEY:-}" \
    bash "$REPO/script/macos" "$@"
}

writes() { grep -c "^defaults write" "$LOG" 2>/dev/null || true; }

@test "macos: --check writes nothing at all" {
  run macos --check
  # Proving it ran: without this, "no writes" also passes when nothing executed.
  echo "$output" | grep -qE "of [0-9]+ settings applied" \
    || { echo "the script did not run: $output"; return 1; }
  [ "$(writes)" -eq 0 ] || { echo "--check wrote $(writes) settings"; return 1; }
  # Reading nvram is fine; setting one is not.
  grep -qE "^(sudo )?nvram [^ ]+=" "$LOG" && { echo "--check set an nvram value"; return 1; }
  [ ! -d "$MHOME/.local/share/dotfiles/macos-defaults" ] \
    || { echo "--check recorded a backup"; return 1; }
}

@test "macos: --check fails and names what has drifted" {
  run macos --check
  [ "$status" -eq 1 ] || { echo "expected a non-zero exit on drift"; return 1; }
  echo "$output" | grep -q "not applied:" || { echo "$output"; return 1; }
  echo "$output" | grep -qE "of [0-9]+ settings applied" || { echo "$output"; return 1; }
}

@test "macos: applying writes the settings, and a second --check is clean" {
  run macos
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(writes)" -gt 15 ] || { echo "only $(writes) writes; the table did not apply"; return 1; }
  echo "$output" | grep -qE "[0-9]+ changed, [0-9]+ already applied, 0 failed" \
    || { echo "$output"; return 1; }

  # The round trip: everything just written must now read back as applied.
  run macos --check
  [ "$status" -eq 0 ] || { echo "a setting did not read back as applied: $output"; return 1; }
  echo "$output" | grep -q ", 0 not" || { echo "$output"; return 1; }
}

@test "macos: a setting that is already correct is not written again" {
  macos >/dev/null 2>&1          # everything applied
  : > "$LOG"
  run macos                      # second pass
  [ "$(writes)" -eq 0 ] || { echo "rewrote $(writes) settings that were already correct"; return 1; }
  echo "$output" | grep -qE "0 changed, [0-9]+ already applied" || { echo "$output"; return 1; }
}

@test "macos: an nvram setting goes to nvram, not defaults" {
  run macos
  grep -q "^sudo nvram StartupMute=" "$LOG" \
    || { echo "StartupMute never reached nvram"; return 1; }
  grep -q "^defaults write nvram" "$LOG" \
    && { echo "an nvram setting was written through defaults"; return 1; }
  return 0
}

@test "macos: a rejected write is counted rather than swallowed" {
  REJECT_KEY="tilesize" run macos
  echo "$output" | grep -q "FAILED: com.apple.dock tilesize" || { echo "$output"; return 1; }
  echo "$output" | grep -qE "[0-9]+ changed, [0-9]+ already applied, 1 failed" \
    || { echo "the failure was not counted: $output"; return 1; }
}

@test "macos: the first run records the previous values and a restore script" {
  run macos
  local backup="$MHOME/.local/share/dotfiles/macos-defaults"
  [ -x "$backup/restore" ] || { echo "no restore script was written"; return 1; }
  [ -s "$backup/login-shell" ] || { echo "the login shell was not recorded"; return 1; }
  grep -q "defaults import\|defaults delete" "$backup/restore" \
    || { echo "the restore script restores nothing"; return 1; }
  grep -q "chsh" "$backup/restore" || { echo "the restore script ignores the login shell"; return 1; }
}

@test "macos: a second run does not overwrite the recorded values" {
  # Overwriting would record the values this script just set as though they were
  # the originals, which destroys the only copy of what the machine looked like.
  macos >/dev/null 2>&1
  local backup="$MHOME/.local/share/dotfiles/macos-defaults"
  echo "sentinel" > "$backup/restore"
  run macos
  echo "$output" | grep -q "already recorded" || { echo "$output"; return 1; }
  [ "$(cat "$backup/restore")" = "sentinel" ] \
    || { echo "the second run overwrote the recorded values"; return 1; }
}

@test "macos: the Terminal profile is left alone outside a desktop session" {
  run macos
  echo "$output" | grep -q "not a desktop session" || { echo "$output"; return 1; }
  grep -q "^open " "$LOG" && { echo "it opened the profile anyway"; return 1; }
  return 0
}

@test "macos: the Dock's icons are only cleared when asked" {
  run macos
  grep -q "persistent-apps" "$LOG" && { echo "the Dock was cleared without --reset-dock"; return 1; }
  : > "$LOG"
  run macos --reset-dock
  grep -q "persistent-apps -array" "$LOG" \
    || { echo "--reset-dock did not clear the Dock"; return 1; }
}
