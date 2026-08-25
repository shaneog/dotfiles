bats_require_minimum_version 1.5.0

load '../helpers/common'

# A first shell on a brand new machine installs every plugin, and that is the
# only time zinit's atclone hooks run -- so hook bugs are invisible on an
# established machine and only bite on a fresh one. Slow and network-bound, so
# opt in with DOTFILES_COLD_CACHE=1.

setup() {
  [ -n "${DOTFILES_COLD_CACHE:-}" ] || skip "set DOTFILES_COLD_CACHE=1 to run"
  COLD_HOME="$(mktemp -d)"
  guard_home "$COLD_HOME"
  ln -s "$REPO/config" "$COLD_HOME/.config"
  ln -s "$REPO/config/zsh/.zshenv" "$COLD_HOME/.zshenv"
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
  _timeout 600 env -i HOME="$COLD_HOME" PATH="$PATH" TERM=xterm-256color \
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

@test "installing from scratch runs every hook without error" {
  run --separate-stderr cold_shell 'true'
  [ "$status" -eq 0 ]
  # atclone hooks that fail leave these behind; zinit itself keeps going
  local bad
  bad="$(printf '%s\n' "$stderr" | grep -iE "permission denied|returned with 1[0-9][0-9]" || true)"
  [ -z "$bad" ] || { echo "failing install hook: $bad"; return 1; }

  # a second shell, with everything installed, must be silent
  run --separate-stderr cold_shell 'true'
  local noise; noise="$(printf '%s\n' "$stderr" | strip_harness_noise)"
  [ -z "$noise" ] || { echo "unexpected stderr once installed: $noise"; return 1; }
}

@test "hook-generated integrations are actually live" {
  cold_shell 'true' >/dev/null 2>&1
  run cold_shell 'print "direnv=$+functions[_direnv_hook] fzf=$+functions[fzf-file-widget]"'
  echo "$output" | grep -q "direnv=1"   # needs atclone to have produced zhook.zsh
  echo "$output" | grep -q "fzf=1"      # needs key-bindings.zsh to have been sourced
}
