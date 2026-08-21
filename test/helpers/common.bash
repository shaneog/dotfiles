#!/usr/bin/env bash
# Shared helpers for the bats suites.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
# Captured while $HOME is still the real one, before any test overrides it.
REAL_HOME="${REAL_HOME:-$HOME}"
export REPO REAL_HOME

# GNU timeout, BSD gtimeout, or nothing (CI runners vary).
_timeout() {
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1;    then timeout "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" "$@"
  else "$@"
  fi
}

# Refuse to run against the real home directory. The helpers below write into
# $HOME, so a stray expansion here would eat the dotfiles they are testing.
guard_home() {
  case "$1" in
    /tmp/*|/private/var/folders/*|/var/folders/*) return 0 ;;
    *) echo "REFUSING: '$1' is not a temp dir" >&2; return 1 ;;
  esac
}

# A disposable $HOME with .config and .zshenv linked into the repo, i.e. what
# script/setup would have produced. Echoes the path.
make_home() {
  local home
  home="$(mktemp -d)"
  guard_home "$home" || return 1
  ln -s "$REPO/config" "$home/.config"
  ln -s "$REPO/config/zsh/.zshenv" "$home/.zshenv"
  mkdir -p "$home/.cache" "$home/.local/share"
  # Reuse an existing plugin cache so tests don't re-clone zinit every run
  if [ -d "$REAL_HOME/.local/share/zinit" ]; then
    ln -s "$REAL_HOME/.local/share/zinit" "$home/.local/share/zinit"
  fi
  echo "$home"
}

# Install a fake base layer into $1, impersonating a managed setup that owns
# ~/.zprofile and ~/.zshrc. Keeps the layering tests hermetic: they behave
# identically on a machine that has no such setup.
install_base_layer() {
  cp "$REPO/test/fixtures/base-layer/dot-zprofile" "$1/.zprofile"
  cp "$REPO/test/fixtures/base-layer/dot-zshrc" "$1/.zshrc"
}

# Put a stub executable named $1 on PATH; its body is read from stdin.
# Echoes the directory holding it, for the caller to prepend to PATH.
stub_cmd() {
  local dir="${BATS_TEST_TMPDIR:-$BATS_SUITE_TMPDIR}/stubs"
  mkdir -p "$dir"
  cat > "$dir/$1"
  chmod +x "$dir/$1"
  echo "$dir"
}

# Run the repo's config as an interactive login shell, with $1 as $HOME.
# tmux autostart is disabled so a test can never spawn a real session.
run_login_shell() {
  local home="$1"; shift
  guard_home "$home" || return 1
  # _timeout is a shell function, so it has to wrap env rather than the reverse
  _timeout 180 env -i HOME="$home" PATH="$PATH" TERM=xterm-256color \
    USER="${USER:-tester}" ZSH_NO_TMUX_AUTOSTART=1 ZSH_NO_ZCOMPILE=1 \
    zsh -lic "$@"
}

# zsh cannot enable ZLE without a controlling terminal, so `zsh -ic` from a test
# harness always emits "can't change option: zle". Verified absent under a real
# pty, so it is harness noise rather than a config problem. Everything else on
# stderr is a genuine failure.
strip_harness_noise() {
  grep -v "can't change option: zle" | grep -v '^[[:space:]]*$' || true
}
