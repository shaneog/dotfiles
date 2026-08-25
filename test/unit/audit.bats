#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# script/audit is what notices upstream rot, and it has shipped two bugs of its
# own: prose mentioning a command was read as an invocation, and a binary whose
# formula has a different name was reported missing. Both are cheap to pin.
#
# The script resolves its own directory, so each test builds a miniature repo in
# a temp directory, drops the real script into it, and puts stub brew and gh on
# PATH. Nothing here touches the network or the real Brewfile.

setup() {
  FIX="$BATS_TEST_TMPDIR/repo"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$FIX/script" "$FIX/config/zsh/lib" "$FIX/config/git" "$STUBS"
  cp "$REPO/script/audit" "$FIX/script/audit"

  # A fixture that passes, for tests to spoil one thing at a time.
  cat > "$FIX/Brewfile" <<'EOF'
brew 'fzf'
brew 'ripgrep'
cask '1password'
EOF
  cat > "$FIX/config/zsh/lib/fzf.zsh" <<'EOF'
export FZF_DEFAULT_COMMAND='rg --files'
EOF
  cat > "$FIX/config/zsh/lib/alias.zsh" <<'EOF'
alias f='fzf'
EOF
  : > "$FIX/config/git/config"

  stub_brew_ok
  stub_gh_ok
}

# brew that reports everything healthy, and echoes back the name it was asked
# for as the token, which is how a rename is detected.
stub_brew_ok() {
  cat > "$STUBS/brew" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "info --json=v2")
    name="$4"
    printf '{"formulae":[{"name":"%s","deprecated":false,"disabled":false}],' "$name"
    printf '"casks":[{"token":"%s","deprecated":false,"disabled":false}]}\n' "$name"
    ;;
  "tap-info "*) exit 0 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$STUBS/brew"
}

stub_gh_ok() {
  cat > "$STUBS/gh" <<'EOF'
#!/bin/sh
case "$1" in
  auth) exit 0 ;;
  api)  printf 'false\t2026-08-01\n' ;;
esac
EOF
  chmod +x "$STUBS/gh"
}

audit() {
  ( cd "$FIX" && PATH="$STUBS:$PATH" ./script/audit )
}

@test "audit: a healthy repo passes" {
  run audit
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  echo "$output" | grep -q "0 failures" || { echo "$output"; return 1; }
}

@test "audit: a deprecated formula fails" {
  cat > "$STUBS/brew" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "info --json=v2")
    printf '{"formulae":[{"name":"%s","deprecated":true,"disabled":false,' "$4"
    printf '"deprecation_reason":"unmaintained"}],"casks":[{"token":"%s","deprecated":false,"disabled":false}]}\n' "$4"
    ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$STUBS/brew"
  run audit
  [ "$status" -eq 1 ] || { echo "expected a failure exit: $output"; return 1; }
  echo "$output" | grep -q "deprecated upstream" || { echo "$output"; return 1; }
}

@test "audit: a renamed token fails" {
  # brew answers with a different token than it was asked for, which is what a
  # rename looks like: windsurf -> devin-desktop.
  cat > "$STUBS/brew" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "info --json=v2")
    printf '{"formulae":[{"name":"%s","deprecated":false,"disabled":false}],' "$4"
    printf '"casks":[{"token":"somethingelse","deprecated":false,"disabled":false}]}\n'
    ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$STUBS/brew"
  run audit
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "was renamed to 'somethingelse'" || { echo "$output"; return 1; }
}

@test "audit: an archived plugin repository fails" {
  echo "zinit light some/plugin" >> "$FIX/config/zsh/lib/fzf.zsh"
  cat > "$STUBS/gh" <<'EOF'
#!/bin/sh
case "$1" in
  auth) exit 0 ;;
  api)  printf 'true\t2026-08-01\n' ;;
esac
EOF
  chmod +x "$STUBS/gh"
  run audit
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "is archived upstream" || { echo "$output"; return 1; }
}

@test "audit: a long-silent repository warns without failing" {
  echo "zinit light some/plugin" >> "$FIX/config/zsh/lib/fzf.zsh"
  cat > "$STUBS/gh" <<'EOF'
#!/bin/sh
case "$1" in
  auth) exit 0 ;;
  api)  printf 'false\t2019-01-01\n' ;;
esac
EOF
  chmod +x "$STUBS/gh"
  run audit
  [ "$status" -eq 0 ] || { echo "a warning must not fail the run: $output"; return 1; }
  echo "$output" | grep -q "no push since 2019" || { echo "$output"; return 1; }
}

@test "audit: a tool the config invokes but nothing installs fails" {
  echo "export FZF_DEFAULT_COMMAND='nosuchtool --files'" > "$FIX/config/zsh/lib/fzf.zsh"
  run audit
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "'nosuchtool' is invoked by config" || { echo "$output"; return 1; }
}

@test "audit: prose mentioning a command is not an invocation" {
  # The bug this pins: a comment reading "cached_init is deliberately not used"
  # was parsed as a dependency on a tool called "deliberately".
  cat >> "$FIX/config/zsh/lib/common.zsh" <<'EOF'
# cached_init is deliberately not used here
# FZF_DEFAULT_COMMAND='imaginarytool --files'
EOF
  run audit
  [ "$status" -eq 0 ] || { echo "a comment was read as an invocation: $output"; return 1; }
}

@test "audit: a formula whose binary has a different name is not reported missing" {
  # nvim comes from neovim, rg from ripgrep, docker from orbstack. Getting
  # this wrong makes the check cry wolf on a correct Brewfile.
  printf "brew 'neovim'\n" >> "$FIX/Brewfile"
  # Named for the package, not the concept: the orphan check below keys on the
  # lib's filename, so editor.zsh would fail for a different reason entirely.
  echo "cached_init nvim nvim --version" > "$FIX/config/zsh/lib/neovim.zsh"
  run audit
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "audit: a lib for a tool nothing installs any more fails" {
  echo 'export PATH="$HOME/.gone/bin:$PATH"' > "$FIX/config/zsh/lib/departed.zsh"
  run audit
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "configures 'departed'" || { echo "$output"; return 1; }
}

@test "audit: a lib that is not about one tool is not treated as an orphan" {
  echo "# general settings" > "$FIX/config/zsh/lib/common.zsh"
  echo "# history settings" > "$FIX/config/zsh/lib/history.zsh"
  run audit
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "audit: a section that cannot run says so rather than passing quietly" {
  # No brew and no gh on PATH at all.
  run env -i HOME="$HOME" PATH="/usr/bin:/bin" bash -c "cd '$FIX' && ./script/audit"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  echo "$output" | grep -q "NOT CHECKED" \
    || { echo "a skipped section must be announced: $output"; return 1; }
}
