#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# tmux will load a config full of options it no longer recognises: the errors go
# where nobody is looking, and the settings simply do not apply. So these assert
# the options that came out the far end rather than that the file parsed.

setup() {
  command -v tmux >/dev/null 2>&1 || skip "tmux is not installed"
  SOCKET="dotfiles-test-$$-${BATS_TEST_NUMBER:-0}"
  # A throwaway $HOME with a stub tpm already in place. The config clones tpm
  # when it is missing, and ~/.config is a symlink to this repo, so without the
  # stub these tests fetch plugins over the network and into the working tree.
  TMUX_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$TMUX_HOME/.config/tmux/plugins/tpm"
  printf '#!/bin/sh\nexit 0\n' > "$TMUX_HOME/.config/tmux/plugins/tpm/tpm"
  chmod +x "$TMUX_HOME/.config/tmux/plugins/tpm/tpm"
}

teardown() {
  [ -n "${SOCKET:-}" ] && tmux -L "$SOCKET" kill-server >/dev/null 2>&1
  return 0
}

# Start a server from the repo's config against the throwaway $HOME.
#
# stdout goes to /dev/null on purpose: the server daemonises and inherits it,
# and a daemon holding the write end of bats's pipe means bats waits for an EOF
# that never comes. That is a ten-minute hang on a runner, not a failure.
start_tmux() {
  (
    unset COLORTERM
    for assignment in "$@"; do export "$assignment"; done
    export HOME="$TMUX_HOME"
    _timeout 30 tmux -L "$SOCKET" -f "$REPO/config/tmux/tmux.conf" \
      new-session -d -s probe >/dev/null 2>"$BATS_TEST_TMPDIR/stderr"
  )
}

show() {
  HOME="$TMUX_HOME" _timeout 15 tmux -L "$SOCKET" show -g "$1" 2>&1
}

@test "tmux: the config loads without tmux rejecting anything" {
  start_tmux
  local err
  err="$(grep '[[:alpha:]]' "$BATS_TEST_TMPDIR/stderr" 2>/dev/null || true)"
  [ -z "$err" ] || { echo "tmux complained on load: $err"; return 1; }
}

@test "tmux: sourcing the config a second time is also silent" {
  # source-file reports what start-up swallows, so this is where a stale option
  # actually shows itself.
  start_tmux
  # _timeout first: it is a shell function, and env can only exec a binary.
  run _timeout 15 env HOME="$TMUX_HOME" tmux -L "$SOCKET" source-file "$REPO/config/tmux/tmux.conf"
  [ -z "$output" ] || { echo "re-sourcing produced: $output"; return 1; }
}

@test "tmux: the status bar is gotham, not tmux's default green" {
  start_tmux
  local status_style; status_style="$(show status-style)"
  echo "$status_style" | grep -q "bg=colour8" \
    || { echo "status bar is not gotham: $status_style"; return 1; }
  echo "$(show message-style)" | grep -q "bg=colour10" \
    || { echo "message style is not gotham: $(show message-style)"; return 1; }
  echo "$(show pane-active-border-style)" | grep -q "fg=colour4" \
    || { echo "pane border is not gotham: $(show pane-active-border-style)"; return 1; }
}

@test "tmux: the basics are what this config asks for" {
  start_tmux
  echo "$(show prefix)" | grep -q "C-a" || { echo "$(show prefix)"; return 1; }
  echo "$(show mode-keys)" | grep -q "vi" || { echo "$(show mode-keys)"; return 1; }
  echo "$(show default-terminal)" | grep -q "tmux-256color" \
    || { echo "terminal is not tmux-256color: $(show default-terminal)"; return 1; }
  echo "$(show history-limit)" | grep -q "50000" || { echo "$(show history-limit)"; return 1; }
}

@test "tmux: status-left carries the placeholder the prefix plugin fills in" {
  # tpm is stubbed here, so the placeholder is still literal. That it survives
  # is the point: the plugin interpolates over it at load, and a status-left
  # without it silently loses the prefix, copy and sync indicators. The VM tier
  # asserts the interpolated form, where the real plugin is installed.
  start_tmux
  echo "$(show status-left)" | grep -qF '#{prefix_highlight}' \
    || { echo "no prefix_highlight placeholder in status-left: $(show status-left)"; return 1; }
  echo "$(show status-right)" | grep -qv "now_playing" \
    || { echo "status-right still calls the removed now-playing script"; return 1; }
}

@test "tmux: copying goes to the system clipboard" {
  start_tmux
  local n
  n="$(HOME="$TMUX_HOME" _timeout 15 tmux -L "$SOCKET" list-keys -T copy-mode-vi 2>/dev/null \
    | grep -c 'copy-pipe-and-cancel pbcopy' || true)"
  [ "${n:-0}" -ge 2 ] \
    || { echo "expected y, Enter and mouse drag to pipe to pbcopy, found $n"; return 1; }
}

@test "tmux: splits open in the current pane's directory" {
  start_tmux
  local n
  n="$(HOME="$TMUX_HOME" _timeout 15 tmux -L "$SOCKET" list-keys 2>/dev/null \
    | grep -c 'pane_current_path' || true)"
  [ "${n:-0}" -ge 3 ] || { echo "expected |, - and c to use pane_current_path, found $n"; return 1; }
}

@test "tmux: 24-bit color is declared only when the terminal claims it" {
  # Declaring RGB unconditionally sends 24-bit escapes to terminals that only
  # advertise 256 -- which is what happens over ssh from something older.
  start_tmux COLORTERM=truecolor
  show terminal-features | grep -q "RGB" \
    || { echo "RGB not declared with COLORTERM=truecolor: $(show terminal-features)"; return 1; }
  tmux -L "$SOCKET" kill-server >/dev/null 2>&1

  start_tmux
  run show terminal-features
  echo "$output" | grep -q "RGB" \
    && { echo "RGB declared with no COLORTERM: $output"; return 1; }
  return 0
}

@test "tmux: the declared plugin set is the intended one" {
  # Named rather than counted, so adding or dropping one is a deliberate edit to
  # this list. The legacy @tpm_plugins spelling is checked for too, since tpm
  # still honours it silently.
  local declared expected legacy
  declared="$(grep -oE "^set -g @plugin '[^']+'" "$REPO/config/tmux/tmux.conf" \
    | sed -E "s/.*'(.*)'/\1/" | sort | tr '\n' ' ')"
  expected="tmux-plugins/tmux-continuum tmux-plugins/tmux-prefix-highlight tmux-plugins/tmux-resurrect tmux-plugins/tpm "
  [ "$declared" = "$expected" ] \
    || { echo "declared plugins changed:"; echo "  got:      $declared"; echo "  expected: $expected"; return 1; }
  legacy="$(grep -cE "^[[:space:]]*set .*@tpm_plugins" "$REPO/config/tmux/tmux.conf" || true)"
  [ "$legacy" -eq 0 ] || { echo "the deprecated @tpm_plugins spelling is back"; return 1; }
}

@test "tmux: the tests themselves fetch nothing" {
  # The bootstrap hook clones tpm when it is absent, over the network and into
  # the working tree. A test that does that is a test that hangs on a runner.
  start_tmux
  local fetched
  fetched="$(ls "$TMUX_HOME/.config/tmux/plugins" 2>/dev/null | tr '\n' ' ' | tr -s ' ')"
  [ "$fetched" = "tpm " ] || { echo "these tests fetched: $fetched"; return 1; }
}
