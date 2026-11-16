#!/usr/bin/env bash
# Shared helpers for the bats suites.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
# Captured while $HOME is still the real one, before any test overrides it.
REAL_HOME="${REAL_HOME:-$HOME}"
# The zsh under test. Set ZSH_BIN to exercise a specific build; tests invoke it
# by absolute path so a hermetic PATH cannot silently change which one runs.
ZSH_BIN="${ZSH_BIN:-$(command -v zsh)}"
export REPO REAL_HOME ZSH_BIN

# Assertions that say what they were looking at. A bare `grep -q` failure prints
# the line of test code and nothing else, which is a poor trade for two lines
# here. `refute_contains` exists because `grep -qv` does not mean what it looks
# like: on multi-line input it passes as soon as any one line lacks the pattern,
# so it can never fail.
assert_contains() {
  local haystack="$1" needle="$2" what="${3:-the output}"
  case "$haystack" in
    *"$needle"*) return 0 ;;
  esac
  printf 'expected %s to contain: %s\nactual:\n%s\n' "$what" "$needle" "$haystack"
  return 1
}

refute_contains() {
  local haystack="$1" needle="$2" what="${3:-the output}"
  case "$haystack" in
    *"$needle"*)
      printf 'expected %s not to contain: %s\nactual:\n%s\n' "$what" "$needle" "$haystack"
      return 1
      ;;
  esac
  return 0
}

assert_equal() {
  local actual="$1" expected="$2" what="${3:-the output}"
  [ "$actual" = "$expected" ] && return 0
  printf 'expected %s to be: %s\nactual:   %s\n' "$what" "$expected" "$actual"
  return 1
}

# Skip a check that cannot run here -- unless this is a CI runner. What a runner
# has installed is the workflow's to decide, so a check that cannot run there is
# a workflow that has stopped installing something, and a skip would go on
# reporting it as a pass. Two harness tests and both Ghostty checks skipped on
# every run for exactly that reason.
skip_unless_ci() {  # why it cannot run
  if [ -n "${CI:-}" ]; then
    echo "NOT CHECKED, on a runner that is meant to check it: $1"
    return 1
  fi
  skip "NOT CHECKED: $1"
}

# For a test of a zsh plugin the Brewfile installs. .zprofile looks for
# Homebrew at /opt/homebrew, so that is where the shell under test finds it.
needs_plugin() {  # the formula
  [ -d "/opt/homebrew/share/$1" ] || skip_unless_ci "$1 is not installed"
}

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

# Link the repo's config into the home at $1 the way script/setup does: a real
# ~/.config holding one link for each entry git tracks, and ~/.zshenv.
link_config() {
  local entry
  mkdir -p "$1/.config"
  git -C "$REPO" ls-files -- config | cut -d/ -f2 | sort -u | while IFS= read -r entry; do
    ln -s "$REPO/config/$entry" "$1/.config/$entry"
  done
  ln -s "$REPO/config/zsh/.zshenv" "$1/.zshenv"
}

# A disposable $HOME with the config linked into the repo, i.e. what
# script/setup would have produced. Echoes the path.
make_home() {
  local home
  home="$(mktemp -d)"
  guard_home "$home" || return 1
  link_config "$home"
  mkdir -p "$home/.cache" "$home/.local/share"
  echo "$home"
}

# Install a fake base layer into $1, impersonating a managed setup that owns
# ~/.zprofile and ~/.zshrc. Keeps the layering tests hermetic: they behave
# identically on a machine that has no such setup.
install_base_layer() {
  cp "$REPO/test/fixtures/base-layer/dot-zprofile" "$1/.zprofile"
  cp "$REPO/test/fixtures/base-layer/dot-zshrc" "$1/.zshrc"
}

# Directory holding stub executables; prepend it to PATH.
stub_dir() {
  local dir="${BATS_TEST_TMPDIR:-$BATS_SUITE_TMPDIR}/stubs"
  mkdir -p "$dir"
  echo "$dir"
}

# Write a stub executable named $1, body read from stdin.
#
# Deliberately does not echo its directory: callers must use stub_dir for that.
# bash 3.2 -- the system bash, and what CI runs bats under -- terminates a
# command substitution at the first unbalanced ")" inside a heredoc, so
# `X="$(stub_cmd foo <<EOF ... case in *bar) ... EOF)"` captures the body and
# re-parses it as code.
stub_cmd() {
  local dir
  dir="$(stub_dir)"
  cat > "$dir/$1"
  chmod +x "$dir/$1"
}

# Run the repo's config as an interactive login shell, with $1 as $HOME.
# tmux autostart is disabled so a test can never spawn a real session.
run_login_shell() {
  local home="$1"; shift
  guard_home "$home" || return 1
  # stdout goes to a file rather than straight to the caller. A login shell can
  # leave a background process behind -- a plugin's daemon, say -- and anything
  # inheriting the shell's stdout holds the write end of the caller's pipe, so a
  # reader waits for an EOF that never arrives. That is a hang rather than a
  # failure: a CI job sat for twenty-nine minutes on one.
  local captured status
  captured="$(mktemp)"
  # SHLVL=1: the shell is one level down from whoever ran the tests, and env -i
  # would hide that. A first-level shell hands its PATH to launchd, which on a
  # Mac is the login session's and not this throwaway home's, so every GUI app
  # opened afterwards would get a PATH inside a temp directory.
  #
  # _timeout is a shell function, so it has to wrap env rather than the reverse
  _timeout 180 env -i HOME="$home" PATH="$PATH" TERM=xterm-256color SHLVL=1 \
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

# zsh cannot enable ZLE without a controlling terminal, so `"$ZSH_BIN" -ic` from a test
# harness always emits "can't change option: zle". Verified absent under a real
# pty, so it is harness noise rather than a config problem. Everything else on
# stderr is a genuine failure.
strip_harness_noise() {
  grep -v "can't change option: zle" \
    | grep -v '^[[:space:]]*$' \
    | grep '[[:alpha:]]' \
    || true
}

# The final filter drops lines with no letters at all, which is what curl
# progress bars are ("####### 100.0%"). A download's progress is not a config
# defect, and any genuine diagnostic contains words.
