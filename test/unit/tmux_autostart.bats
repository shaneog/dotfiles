#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

setup() {
  TMUX_LOG="$BATS_TEST_TMPDIR/tmux.log"
  : > "$TMUX_LOG"
  STUBS="$(stub_cmd tmux <<'STUB'
#!/bin/sh
echo "$*" >> "$TMUX_LOG"
case "$*" in
  *has-session*)  exit "${STUB_HAS_SESSION:-1}" ;;
  *list-clients*) printf '%s' "${STUB_CLIENTS:-}" ;;
esac
exit 0
STUB
)"
}

# Call the real autoloaded function with a controlled environment.
autostart() {
  env -i HOME="$HOME" PATH="$STUBS:/usr/bin:/bin" USER=some.user \
      TMUX_LOG="$TMUX_LOG" XDG_CONFIG_HOME="$REPO/config" \
      STUB_HAS_SESSION="${STUB_HAS_SESSION:-1}" STUB_CLIENTS="${STUB_CLIENTS:-}" \
      "$@" \
      zsh -fi -c "fpath=($REPO/config/zsh/autoload \$fpath)
                  autoload -Uz tmux_autostart
                  tmux_autostart"
}

@test "starts a session from Terminal.app" {
  autostart TERM_PROGRAM=Apple_Terminal
  grep -q 'new-session -s someuser' "$TMUX_LOG"
}

@test "session name strips dots from the username" {
  autostart TERM_PROGRAM=Apple_Terminal
  ! grep -q 'some.user' "$TMUX_LOG"
}

@test "uses the repo tmux.conf rather than the default" {
  autostart TERM_PROGRAM=Apple_Terminal
  grep -q -- "-f $REPO/config/tmux/tmux.conf" "$TMUX_LOG"
}

@test "does not fire from a vscode terminal" {
  autostart TERM_PROGRAM=vscode
  [ ! -s "$TMUX_LOG" ]
}

@test "does not fire when TERM_PROGRAM is unset (scripts, agents, ssh)" {
  autostart
  [ ! -s "$TMUX_LOG" ]
}

@test "does not fire from other terminal emulators" {
  local prog
  for prog in iTerm.app ghostty WezTerm WarpTerminal JetBrains-JediTerm tmux; do
    : > "$TMUX_LOG"
    autostart TERM_PROGRAM="$prog"
    [ ! -s "$TMUX_LOG" ] || { echo "fired for $prog"; return 1; }
  done
}

@test "does not nest inside an existing tmux session" {
  autostart TERM_PROGRAM=Apple_Terminal TMUX=/tmp/sock,123,0
  [ ! -s "$TMUX_LOG" ]
}

@test "honours the ZSH_NO_TMUX_AUTOSTART opt-out" {
  autostart TERM_PROGRAM=Apple_Terminal ZSH_NO_TMUX_AUTOSTART=1
  [ ! -s "$TMUX_LOG" ]
}

@test "does not fire in a non-interactive shell" {
  env -i HOME="$HOME" PATH="$STUBS:/usr/bin:/bin" USER=some.user \
      TMUX_LOG="$TMUX_LOG" TERM_PROGRAM=Apple_Terminal \
      zsh -f -c "fpath=($REPO/config/zsh/autoload \$fpath)
                 autoload -Uz tmux_autostart
                 tmux_autostart"
  [ ! -s "$TMUX_LOG" ]
}

@test "does not fire when tmux is not installed" {
  env -i HOME="$HOME" PATH="/usr/bin:/bin" USER=some.user \
      TMUX_LOG="$TMUX_LOG" TERM_PROGRAM=Apple_Terminal \
      zsh -fi -c "fpath=($REPO/config/zsh/autoload \$fpath)
                  autoload -Uz tmux_autostart
                  tmux_autostart"
  [ ! -s "$TMUX_LOG" ]
}

@test "attaches to an existing session with no clients" {
  STUB_HAS_SESSION=0 STUB_CLIENTS= autostart TERM_PROGRAM=Apple_Terminal
  grep -q 'attach-session -t someuser' "$TMUX_LOG"
}

@test "never steals a session that already has a client" {
  STUB_HAS_SESSION=0 STUB_CLIENTS='/dev/ttys001: 1 [80x24 xterm]' \
    autostart TERM_PROGRAM=Apple_Terminal
  ! grep -q 'attach-session' "$TMUX_LOG"
  ! grep -q 'new-session' "$TMUX_LOG"
}
