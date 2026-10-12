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
  # `run list` is asked twice per workflow: once bounded by --created, once not.
  run)
    case "$*" in
      *--created*) printf '%s\n' "${STUB_RECENT:-0}" ;;
      *)           printf '%s\n' "${STUB_EVER:-0}" ;;
    esac ;;
esac
EOF
  chmod +x "$STUBS/gh"
}

# A workflow that runs on a cron, which is what the schedule section looks for.
given_scheduled_workflow() {
  mkdir -p "$FIX/.github/workflows"
  printf 'on:\n  schedule:\n    - cron: %s0 7 * * 1%s\n' "'" "'" > "$FIX/.github/workflows/weekly.yml"
}

audit_gh() {
  ( cd "$FIX" && PATH="$STUBS:$PATH" STUB_RECENT="$1" STUB_EVER="$2" ./script/audit )
}

# CI is unset unless a test sets it: the machine-drift section skips itself when
# it sees CI, so inheriting the runner's would make those tests assert against a
# section that never ran -- which is exactly how they first failed.
audit() {
  ( cd "$FIX" && PATH="$STUBS:$PATH" CI="${CI_OVERRIDE:-}" ./script/audit )
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

@test "audit: a cron that has stopped firing warns" {
  # The failure this exists for: GitHub disables schedules on a repository with
  # no pushes for 60 days, and every rot check here runs on one. A dead cron is
  # silent -- the workflow simply never runs again.
  given_scheduled_workflow
  run audit_gh 0 1
  [ "$status" -eq 0 ] || { echo "a warning must not fail the run: $output"; return 1; }
  echo "$output" | grep -q "has not fired on schedule since before" \
    || { echo "a dead cron went unreported: $output"; return 1; }
  # Counted, not just printed. Regression: this section ran after the summary had
  # already been printed, so a dead cron warned underneath "0 warnings".
  echo "$output" | grep -q "0 failures, 1 warnings" \
    || { echo "the warning never reached the summary: $output"; return 1; }
}

@test "audit: a cron that is still firing is not reported" {
  given_scheduled_workflow
  run audit_gh 1 1
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  echo "$output" | grep -q "weekly.yml fired on schedule since" \
    || { echo "$output"; return 1; }
  echo "$output" | grep -q "has not fired" \
    && { echo "a live cron was reported as dead: $output"; return 1; }
  return 0
}

@test "audit: a cron too new to have fired yet is not a warning" {
  given_scheduled_workflow
  run audit_gh 0 0
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  echo "$output" | grep -q "first scheduled run still pending" \
    || { echo "$output"; return 1; }
}

@test "audit: an archived neovim plugin fails too" {
  # lazy.nvim pins its plugins in a committed lockfile and never updates itself,
  # so an archived one would sit there untouched. The zinit list was checked for
  # this from the start and the Lua specs were not.
  mkdir -p "$FIX/config/nvim/lua"
  printf 'return {\n  { "someone/dead.nvim" },\n}\n' > "$FIX/config/nvim/lua/plugins.lua"
  cat > "$STUBS/gh" <<'EOF'
#!/bin/sh
case "$1" in
  auth) exit 0 ;;
  api)  printf 'true\t2026-08-01\n' ;;
  run)  printf '0\n' ;;
esac
EOF
  chmod +x "$STUBS/gh"
  run audit
  [ "$status" -eq 1 ] || { echo "an archived plugin must fail the run: $output"; return 1; }
  echo "$output" | grep -q "someone/dead.nvim is archived upstream" || { echo "$output"; return 1; }
}

@test "audit: a machine that has drifted is reported, and counted" {
  # The gap this closes: script/macos --check knows about a setting the OS reset
  # or a PAM module copy left behind by an upgrade, and nothing ran it. The
  # counting half matters too -- `warn` inside a piped while-loop increments in a
  # subshell, so the summary would have said 0 warnings beneath two of them.
  cat > "$FIX/script/macos" <<'EOF'
#!/bin/sh
echo "  not applied: com.apple.dock tilesize is 48, wanted 32 (icon size)"
echo "  not applied: pam sudo_local is unset, wanted authsufficientpam_tid.so (Touch ID)"
echo "31 of 33 settings applied, 2 not"
exit 1
EOF
  chmod +x "$FIX/script/macos"
  run audit
  [ "$status" -eq 0 ] || { echo "drift is a warning, not a failure: $output"; return 1; }
  echo "$output" | grep -q "com.apple.dock tilesize" || { echo "$output"; return 1; }
  echo "$output" | grep -q "pam sudo_local is unset" || { echo "$output"; return 1; }
  echo "$output" | grep -q "0 failures, 3 warnings" \
    || { echo "the warnings never reached the summary: $output"; return 1; }
}

@test "audit: a machine with no drift is one ok line" {
  cat > "$FIX/script/macos" <<'EOF'
#!/bin/sh
echo "33 of 33 settings applied, 0 not"
EOF
  chmod +x "$FIX/script/macos"
  run audit
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  echo "$output" | grep -q "33 of 33 settings applied" || { echo "$output"; return 1; }
  echo "$output" | grep -q "0 failures, 0 warnings" || { echo "$output"; return 1; }
}

@test "audit: the machine-drift section skips itself on a runner, out loud" {
  # A runner has had none of these settings applied, so every one would read as
  # drift and say nothing about the machine this repo is for. Skipped, and named
  # in NOT CHECKED rather than quietly passing.
  cat > "$FIX/script/macos" <<'EOF'
#!/bin/sh
echo "  not applied: com.apple.dock tilesize is 48, wanted 32 (icon size)"
exit 1
EOF
  chmod +x "$FIX/script/macos"
  CI_OVERRIDE=true run audit
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  echo "$output" | grep -q "not checked: a CI runner" || { echo "$output"; return 1; }
  echo "$output" | grep -q "NOT CHECKED:.*machine-drift" || { echo "$output"; return 1; }
  refute_contains "$output" "com.apple.dock tilesize" "the report"
}
