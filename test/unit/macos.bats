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

  # A stand-in for /etc/pam.d/sudo_local.template, same shape as Apple's.
  cat > "$MHOME/sudo_local.template" <<'TEMPLATE'
# sudo_local: local config file which survives system update and is included for sudo
# uncomment following line to enable Touch ID for sudo
#auth       sufficient     pam_tid.so
TEMPLATE

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
  # Same reasoning as the sudo stub: it has to do the copy, or the pam branch
  # looks like it worked while nothing moved. The -o/-g flags are dropped because
  # a test cannot honour them; that they were passed is asserted from the log.
  cat > "$STUBS/install" <<'INSTALL'
#!/bin/sh
printf 'install %s\n' "$*" >> "$CALL_LOG"
dir=""; args=""
while [ $# -gt 0 ]; do
  case "$1" in
    -d) dir=1 ;;
    -o|-g|-m) shift ;;
    *) args="$args $1" ;;
  esac
  shift
done
if [ -n "$dir" ]; then mkdir -p $args; else
  set -- $args; mkdir -p "$(dirname "$2")"; cp "$1" "$2"
fi
INSTALL

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
    PAM_SUDO_LOCAL="$MHOME/sudo_local" \
    PAM_SUDO_TEMPLATE="${PAM_SUDO_TEMPLATE:-$MHOME/sudo_local.template}" \
    PAM_REATTACH_SRC="${PAM_REATTACH_SRC:-$MHOME/absent/pam_reattach.so}" \
    PAM_REATTACH_DEST="${PAM_REATTACH_DEST:-$MHOME/pam/pam_reattach.so}" \
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

@test "macos: Touch ID for sudo goes through Apple's hook, with sudo" {
  # Authentication, not authorisation: this replaces the password prompt and
  # grants nothing. sudo_local rather than /etc/pam.d/sudo, because Apple includes
  # the former and an OS update overwrites the latter.
  run macos
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  grep -qE '^auth[[:space:]]+sufficient[[:space:]]+pam_tid.so' "$MHOME/sudo_local" \
    || { echo "pam_tid never reached sudo_local: $(cat "$MHOME/sudo_local" 2>&1)"; return 1; }
  grep -q "^sudo tee .*sudo_local" "$LOG" \
    || { echo "the file was written without sudo: $(cat "$LOG")"; return 1; }
  # The machine's real PAM config is never a target, even under a stubbed sudo.
  grep -qE "tee +/etc/pam.d/sudo($| )" "$LOG" \
    && { echo "wrote /etc/pam.d/sudo itself"; return 1; }
  return 0
}

@test "macos: --check reports Touch ID before it is configured, and writes nothing" {
  run macos --check
  echo "$output" | grep -q "not applied: pam sudo_local" || { echo "$output"; return 1; }
  [ ! -e "$MHOME/sudo_local" ] || { echo "--check wrote the pam file"; return 1; }
}

@test "macos: the pam line is the one this OS ships, not a hand-written copy" {
  # Against the real template on purpose: it is the only way to notice Apple
  # respelling the line or moving the file. Everything else here is hermetic.
  [ -r /etc/pam.d/sudo_local.template ] \
    || skip "this macOS ships no /etc/pam.d/sudo_local.template"
  PAM_SUDO_TEMPLATE=/etc/pam.d/sudo_local.template run macos
  grep -qE '^auth[[:space:]]+sufficient[[:space:]]+pam_tid.so' "$MHOME/sudo_local" \
    || { echo "Apple's template no longer yields the expected line: $(cat "$MHOME/sudo_local" 2>&1)"; return 1; }
}

@test "macos: the restore script undoes the Touch ID change" {
  # The first run promises a way back. Before this, the one setting it could not
  # undo was the PAM file -- the restore script never mentioned it.
  run macos
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  local restore="$MHOME/.local/share/dotfiles/macos-defaults/restore"
  [ -x "$restore" ] || { echo "no restore script"; return 1; }
  grep -q "sudo rm -f .*sudo_local" "$restore" \
    || { echo "restore does not remove the pam file it created:"; cat "$restore"; return 1; }
}

@test "macos: an existing sudo_local is kept, and the restore puts it back" {
  # A machine that already had Touch ID configured, or had this file written by
  # something else, must not lose it to a first run.
  printf 'auth sufficient pam_something_else.so\n' > "$MHOME/sudo_local"
  run macos
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  local dir="$MHOME/.local/share/dotfiles/macos-defaults"
  grep -q "pam_something_else" "$dir/sudo_local" \
    || { echo "the previous file was not recorded"; return 1; }
  grep -q "sudo cp ./sudo_local" "$dir/restore" \
    || { echo "restore does not put it back:"; cat "$dir/restore"; return 1; }
}

@test "macos: without pam-reattach installed, only pam_tid is configured" {
  # script/bootstrap runs this before the Brewfile, so a new machine must get
  # working Touch ID now rather than a file naming a module that is not there.
  run macos
  grep -qE '^auth[[:space:]]+sufficient[[:space:]]+pam_tid.so' "$MHOME/sudo_local" \
    || { echo "$(cat "$MHOME/sudo_local" 2>&1)"; return 1; }
  grep -q pam_reattach "$MHOME/sudo_local" \
    && { echo "named a module that is not installed"; return 1; }
  run macos --check
  [ "$status" -eq 0 ] || { echo "drifted against its own write: $output"; return 1; }
}

@test "macos: pam_reattach is loaded from a root-owned copy, ahead of pam_tid" {
  # The order is load-bearing: pam_reattach reattaches this process to the GUI
  # session, which is what pam_tid then looks for. Reversed, Touch ID in a tmux
  # pane silently falls back to the password.
  mkdir -p "$MHOME/brewlib"
  printf 'module\n' > "$MHOME/brewlib/pam_reattach.so"
  PAM_REATTACH_SRC="$MHOME/brewlib/pam_reattach.so" run macos
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }

  local file="$MHOME/sudo_local"
  local reattach tid
  reattach="$(grep -n pam_reattach "$file" | cut -d: -f1)"
  tid="$(grep -n pam_tid "$file" | cut -d: -f1)"
  [ -n "$reattach" ] || { echo "no reattach line: $(cat "$file")"; return 1; }
  [ "$reattach" -lt "$tid" ] \
    || { echo "pam_reattach must precede pam_tid: $(cat "$file")"; return 1; }

  # Root-owned copy, not the group-writable prefix Homebrew installs into.
  grep -q "^sudo install -o root -g wheel -m 0644 .*brewlib/pam_reattach.so $MHOME/pam/" "$LOG" \
    || { echo "the module was not installed root-owned: $(grep install "$LOG")"; return 1; }
  refute_contains "$(cat "$file")" "brewlib" "the PAM stack"
}

@test "macos: a module copy that has fallen behind is reported as drift" {
  # `brew upgrade pam-reattach` leaves the root-owned copy stale, and nothing in
  # the file itself changes, so --check has to compare the two.
  mkdir -p "$MHOME/brewlib"
  printf 'v1\n' > "$MHOME/brewlib/pam_reattach.so"
  PAM_REATTACH_SRC="$MHOME/brewlib/pam_reattach.so" run macos
  PAM_REATTACH_SRC="$MHOME/brewlib/pam_reattach.so" run macos --check
  [ "$status" -eq 0 ] || { echo "drifted straight after applying: $output"; return 1; }

  printf 'v2\n' > "$MHOME/brewlib/pam_reattach.so"
  PAM_REATTACH_SRC="$MHOME/brewlib/pam_reattach.so" run macos --check
  [ "$status" -eq 1 ] || { echo "a stale copy went unreported: $output"; return 1; }
  echo "$output" | grep -q "stale-module-copy" || { echo "$output"; return 1; }
}
