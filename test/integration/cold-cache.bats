bats_require_minimum_version 1.5.0

load '../helpers/common'

# A first shell on a brand new machine installs zinit and every plugin, and
# generates each tool's cached init. Nothing else runs that path, so a bug in it
# is invisible on an established machine and only bites on a fresh one. Slow
# and network-bound, so opt in with DOTFILES_COLD_CACHE=1.

setup() {
  [ -n "${DOTFILES_COLD_CACHE:-}" ] || skip "set DOTFILES_COLD_CACHE=1 to run"
  COLD_HOME="$(mktemp -d)"
  guard_home "$COLD_HOME"
  link_config "$COLD_HOME"
  mkdir -p "$COLD_HOME/.cache" "$COLD_HOME/.local/share"   # deliberately no zinit
}

teardown() {
  if [ -n "${COLD_HOME:-}" ] && guard_home "$COLD_HOME"; then
    rm -rf "$COLD_HOME"
  fi
  return 0
}

# Same file-not-pipe capture as run_login_shell, and for the same reason: the
# first shell on a machine with no plugins installed is exactly where a daemon
# gets started, and this job has no warm-up step ahead of it.
cold_shell() {
  local captured status
  captured="$(mktemp)"
  _timeout 600 env -i HOME="$COLD_HOME" PATH="$PATH" TERM=xterm-256color SHLVL=1 \
    USER="${USER:-tester}" ZSH_NO_TMUX_AUTOSTART=1 ZSH_NO_ZCOMPILE=1 \
    "$ZSH_BIN" -lic "$@" > "$captured" 2> "$captured.err"
  status=$?
  cat "$captured"
  # Replayed rather than passed through: a child that inherits stderr holds that
  # pipe just as surely as stdout, and tests capture stderr separately.
  cat "$captured.err" >&2
  rm -f "$captured" "$captured.err"
  return "$status"
}

@test "installing from scratch reports no error, and the next shell is silent" {
  run --separate-stderr cold_shell 'true'
  [ "$status" -eq 0 ]
  # an install step that fails leaves these behind; zinit itself keeps going
  local bad
  bad="$(printf '%s\n' "$stderr" | grep -iE "permission denied|returned with 1[0-9][0-9]" || true)"
  [ -z "$bad" ] || { echo "failing install step: $bad"; return 1; }

  # a second shell, with everything installed, must be silent
  run --separate-stderr cold_shell 'true'
  local noise; noise="$(printf '%s\n' "$stderr" | strip_harness_noise)"
  [ -z "$noise" ] || { echo "unexpected stderr once installed: $noise"; return 1; }
}

@test "the integrations a first shell generates are live" {
  cold_shell 'true' >/dev/null 2>&1
  run cold_shell 'print "direnv=$+functions[_direnv_hook] fzf=$+functions[fzf-file-widget]"'
  # both come from cached_init, which has nothing cached on a new machine
  echo "$output" | grep -q "direnv=1"
  echo "$output" | grep -q "fzf=1"
}

@test "a new machine installs everything at the commit pins.zsh names" {
  cold_shell 'true' >/dev/null 2>&1
  # The commit itself, and not a branch whose tip is that commit today: HEAD
  # names a branch for a plugin installed without its pin.
  local zinit="$COLD_HOME/.local/share/zinit" repo commit count=0
  while read -r repo commit; do
    assert_equal "$(cat "$(pin_checkout "$zinit" "$repo")/.git/HEAD")" "$commit" \
      "what $repo has checked out"
    count=$((count + 1))
  done < <(pins)
  [ "$count" -ge 5 ] || { echo "only $count pins were checked"; return 1; }

}
