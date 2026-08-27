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

tm() {
  HOME="$TMUX_HOME" _timeout 15 tmux -L "$SOCKET" "$@"
}

# The entry the status line renders for one window, styles included. #{E:...}
# expands the format the way the status bar does, which is the only place the
# interaction between window-status-format and the -style options is visible.
window_entry() {
  local rendered; rendered="$(tm display-message -p '#{E:status-format[0]}')"
  local seg="${rendered##*range=window|$1}"
  printf '%s' "${seg%%pop-default*}"
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
  # The prompt is a format, not a word: it renders whatever `set -g prefix` says,
  # so the indicator cannot drift out of step with the actual key.
  echo "$(show @prefix_highlight_prefix_prompt)" | grep -qF '#{prefix}' \
    || { echo "the prefix prompt is hardcoded: $(show @prefix_highlight_prefix_prompt)"; return 1; }
  refute_contains "$(show status-right)" "now_playing" "status-right"
}

@test "tmux: copying goes to the system clipboard" {
  start_tmux
  # Named rather than counted: a count passes when a binding is lost and another
  # is added.
  local keys
  keys="$(HOME="$TMUX_HOME" _timeout 15 tmux -L "$SOCKET" list-keys -T copy-mode-vi 2>/dev/null || true)"
  # Field-aware: list-keys pads its columns, so a fixed-string match on
  # "copy-mode-vi y" never lines up.
  local key
  for key in y Enter MouseDragEnd1Pane; do
    echo "$keys" | awk -v k="$key" \
      '$3 == "copy-mode-vi" && $4 == k && /pbcopy/ { found = 1 } END { exit !found }' \
      || { echo "$key does not copy to the clipboard"; return 1; }
  done
}

@test "tmux: splits open in the current pane's directory" {
  start_tmux
  local keys
  keys="$(HOME="$TMUX_HOME" _timeout 15 tmux -L "$SOCKET" list-keys 2>/dev/null || true)"
  local key
  for key in '|' '-' c; do
    echo "$keys" | awk -v k="$key" \
      '$3 == "prefix" && $4 == k && /pane_current_path/ { found = 1 } END { exit !found }' \
      || { echo "$key does not open in the current pane's directory"; return 1; }
  done
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

# tmux settles a window name on its own clock, so the value has to be polled;
# reading it once asserts against whatever was there a moment ago.
wait_for() {  # window, format, expected
  local i=0
  until [ "$(tm display-message -p -t "$1" "$2")" = "$3" ]; do
    i=$((i + 1))
    [ "$i" -lt 24 ] || return 1
    sleep 0.25
  done
}

@test "tmux: a window is named for its directory" {
  start_tmux
  mkdir -p "$BATS_TEST_TMPDIR/some-repo"
  local w; w="$(tm new-window -P -F '#{window_id}' -c "$BATS_TEST_TMPDIR/some-repo")"
  wait_for "$w" '#{window_name}' 'some-repo' \
    || { echo "named [$(tm display-message -p -t "$w" '#{window_name}')], expected some-repo"; return 1; }
}

@test "tmux: the name follows a cd" {
  # The case that matters in use: a window opens in $HOME, so the name is only
  # useful if it tracks the shell into a repo. `zsh -f` for the pane, because a
  # shell loading this repo's config spends its first seconds installing plugins
  # and the keys below would be typed before there is a prompt to take them.
  start_tmux
  mkdir -p "$BATS_TEST_TMPDIR/home-ish" "$BATS_TEST_TMPDIR/some-service"
  local w
  w="$(tm new-window -P -F '#{window_id}' -c "$BATS_TEST_TMPDIR/home-ish" zsh -f)"
  wait_for "$w" '#{window_name}' 'home-ish' || { echo "the window never auto-named"; return 1; }

  tm send-keys -t "$w" "cd $BATS_TEST_TMPDIR/some-service" Enter
  wait_for "$w" '#{window_name}' 'some-service' \
    || { echo "after cd the name is still [$(tm display-message -p -t "$w" '#{window_name}')]"; return 1; }
}

@test "tmux: a name given by hand is not overwritten" {
  # tmux turns automatic-rename off for a window renamed by hand. Asserted as
  # behaviour rather than as the option: a deliberate name that reverts on the
  # next cd is worse than no automatic naming at all.
  start_tmux
  mkdir -p "$BATS_TEST_TMPDIR/before" "$BATS_TEST_TMPDIR/after"
  local w; w="$(tm new-window -P -F '#{window_id}' -c "$BATS_TEST_TMPDIR/before")"
  wait_for "$w" '#{window_name}' 'before' || { echo "the window never auto-named"; return 1; }

  tm rename-window -t "$w" mine
  tm respawn-pane -k -t "$w" -c "$BATS_TEST_TMPDIR/after"
  wait_for "$w" '#{b:pane_current_path}' 'after' \
    || { echo "the pane never moved directory"; return 1; }
  assert_equal "$(tm display-message -p -t "$w" '#{window_name}')" 'mine' "the window name"
}

@test "tmux: a window with activity says so in the status line" {
  # An inline #[fg=...] in window-status-format is applied after
  # window-status-activity-style and overrides it, so the alert gets styled and
  # then un-styled. Asserting the option is set proves nothing; this asserts
  # what the status bar actually draws.
  start_tmux
  tm new-window -t probe: >/dev/null
  tm select-window -t probe:1
  tm send-keys -t probe:2 'printf "output\n"' Enter

  local i=0
  until [ "$(tm display-message -p -t probe:2 '#{window_activity_flag}')" = 1 ]; do
    i=$((i + 1))
    [ "$i" -lt 20 ] || { echo "window 2 never registered activity"; return 1; }
    sleep 0.25
  done

  local flags entry
  flags="$(tm display-message -p -t probe:2 '#{window_flags}')"
  assert_contains "$flags" "#" "window 2's flags"

  entry="$(window_entry 2)"
  assert_contains "$entry" "$flags" "the status line entry for window 2"
  assert_contains "$entry" "fg=colour4" "the alert colour on window 2"
  # Anything that sets a colour after the alert style undoes it.
  refute_contains "${entry#*fg=colour4}" "fg=colour" "window 2's entry after the alert style"
}

@test "tmux: a zoomed pane is visible in the current window's entry" {
  # #F is always '*' for the current window, so the zoom flag is conditional
  # rather than free. Both states are checked: a flag that is always shown is as
  # useless as one that never is.
  start_tmux
  tm split-window -t probe:1 >/dev/null
  refute_contains "$(window_entry 1)" "Z" "the unzoomed window 1 entry"
  tm resize-pane -t probe:1 -Z
  assert_contains "$(window_entry 1)" "Z" "the zoomed window 1 entry"
}

@test "tmux: the key tables do not depend on \$EDITOR" {
  # tmux infers mode-keys and status-keys from $EDITOR, so each of these lines
  # only proves itself in the environment where the inference disagrees with it.
  # Regression: asserting mode-keys=vi with this repo's own EDITOR=nvim could not
  # fail -- tmux reads the "vi" in "nvim" and defaults to vi anyway.
  # VISUAL as well as EDITOR: tmux consults VISUAL first, so setting EDITOR
  # alone leaves the inference intact and the assertion unable to fail.
  start_tmux EDITOR=nano VISUAL=nano
  assert_contains "$(show mode-keys)" "vi" "mode-keys with a non-vi editor"
  tm kill-server 2>/dev/null || true

  # And the reverse: with a vi-ish EDITOR tmux would default status-keys to vi,
  # so emacs at the command prompt is this config's doing.
  start_tmux EDITOR=nvim
  assert_contains "$(show status-keys)" "emacs" "status-keys with a vi EDITOR"
}

@test "tmux: a pane runs the shell this repo configures" {
  # default-command. Load-bearing rather than cosmetic: it is why a pane gets
  # this repo's zsh config at all. SHELL is deliberately bash here -- with a zsh
  # login shell tmux would run zsh regardless and the assertion could not fail.
  #
  # Read from the process rather than pane_current_command, which is unreliable
  # while no client is attached.
  start_tmux SHELL=/bin/bash
  local pid comm
  pid="$(tm display-message -p '#{pane_pid}')"
  [ -n "$pid" ] || { echo "no pane pid"; return 1; }
  comm="$(ps -o comm= -p "$pid" | tr -d ' ')"
  assert_contains "$comm" "zsh" "the process running in the pane"
}

@test "tmux: pane movement and resizing are the vim keys" {
  # Named rather than counted: a count still passes when one binding is lost and
  # another gained.
  start_tmux
  local keys
  keys="$(tm list-keys 2>/dev/null || true)"
  local pair
  for pair in "h select-pane -L" "j select-pane -D" "k select-pane -U" "l select-pane -R" \
              "H resize-pane -L" "J resize-pane -D" "K resize-pane -U" "L resize-pane -R"; do
    set -- $pair
    # The key is the field after "prefix", not a fixed column: a repeatable
    # binding carries -r before -T and shifts everything along.
    echo "$keys" | awk -v k="$1" -v cmd="$2" -v dir="$3" \
      '{ key = "" ; for (i = 1; i < NF; i++) if ($i == "prefix") key = $(i + 1) }
       key == k && $0 ~ cmd && $0 ~ dir { found = 1 } END { exit !found }' \
      || { echo "prefix $1 does not run $2 $3"; return 1; }
  done

  # C-a reaches the program inside the pane, which is the whole point of picking
  # a prefix a shell also uses.
  echo "$keys" | awk '{ key = "" ; for (i = 1; i < NF; i++) if ($i == "prefix") key = $(i + 1) }
       key == "C-a" && /send-prefix/ { f = 1 } END { exit !f }' \
    || { echo "prefix C-a does not send the prefix through"; return 1; }
}
