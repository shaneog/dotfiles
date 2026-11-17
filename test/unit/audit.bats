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

audit() {
  ( cd "${AUDIT_DIR:-$FIX}" && PATH="$STUBS:$PATH" ./script/audit )
}

# The audit asks zsh which words are the shell's own.
whence_works() { zsh -fc 'whence -w dirs' >/dev/null 2>&1; }

# git for the fixture, with nothing of the machine's own config: a signing key
# or a hook there is not the fixture's to trigger.
fix_git() {
  env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    git -C "$FIX" -c user.name=t -c user.email=t@example.invalid \
    -c commit.gpgsign=false -c init.defaultBranch=main "$@"
}

# The fixture as a repository whose Neovim lockfile was last committed on $1.
given_lockfile_committed() {  # date
  mkdir -p "$FIX/config/nvim"
  echo '{}' > "$FIX/config/nvim/lazy-lock.json"
  fix_git init -q
  fix_git add -A
  GIT_AUTHOR_DATE="$1T12:00:00" GIT_COMMITTER_DATE="$1T12:00:00" fix_git commit -qm "lockfile"
}

@test "audit: a healthy repo passes" {
  run audit
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  echo "$output" | grep -q "0 failures" || { echo "$output"; return 1; }
}

@test "audit: its working files go where TMPDIR says, and are gone afterwards" {
  local scratch="$BATS_TEST_TMPDIR/tmp" seen="$BATS_TEST_TMPDIR/seen"
  mkdir -p "$scratch"
  mkdir -p "$FIX/config/tmux"
  echo "set -g @plugin 'some/plugin'" > "$FIX/config/tmux/tmux.conf"
  # gh is asked about that plugin partway through, which is the only moment the
  # working files can be seen from outside.
  cat > "$STUBS/gh" <<'EOF'
#!/bin/sh
case "$1" in
  auth) exit 0 ;;
  api)  ls -A "$TMPDIR" > "$SEEN"; printf 'false\t2026-08-01\n' ;;
  run)  echo 0 ;;
esac
EOF
  chmod +x "$STUBS/gh"
  TMPDIR="$scratch" SEEN="$seen" run audit
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ -s "$seen" ] || { echo "nothing was under TMPDIR while the audit ran"; return 1; }
  assert_equal "$(ls -A "$scratch")" "" "left behind in TMPDIR"
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

@test "audit: a deprecated cask in the opt-in Brewfile fails too" {
  printf "cask 'stream-deck'\n" > "$FIX/Brewfile.desk"
  cat > "$STUBS/brew" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "info --json=v2")
    case "$4" in stream-deck) deprecated=true ;; *) deprecated=false ;; esac
    printf '{"formulae":[{"name":"%s","deprecated":false,"disabled":false}],' "$4"
    printf '"casks":[{"token":"%s","deprecated":%s,"disabled":false,' "$4" "$deprecated"
    printf '"deprecation_reason":"discontinued"}]}\n'
    ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$STUBS/brew"
  run audit
  [ "$status" -eq 1 ] || { echo "expected a failure exit: $output"; return 1; }
  echo "$output" | grep -q "cask 'stream-deck' is deprecated upstream" || { echo "$output"; return 1; }
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
  mkdir -p "$FIX/config/tmux"
  echo "set -g @plugin 'some/plugin'" > "$FIX/config/tmux/tmux.conf"
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
  mkdir -p "$FIX/config/tmux"
  echo "set -g @plugin 'some/plugin'" > "$FIX/config/tmux/tmux.conf"
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

@test "audit: an alias for a shell builtin needs no package" {
  whence_works || skip_unless_ci "zsh is not installed"
  echo "alias d='dirs -v'" >> "$FIX/config/zsh/lib/alias.zsh"
  run audit
  [ "$status" -eq 0 ] || { echo "a builtin was read as a missing tool: $output"; return 1; }
}

@test "audit: an alias is checked for its command, not the modifier before it" {
  # ripgrep is in the fixture's Brewfile, and noglob is in nobody's.
  echo "alias search='noglob rg'" >> "$FIX/config/zsh/lib/alias.zsh"
  run audit
  [ "$status" -eq 0 ] || { echo "a modifier was read as a missing tool: $output"; return 1; }
}

@test "audit: a modifier does not hide a command nothing installs" {
  echo "alias search='noglob nosuchtool'" >> "$FIX/config/zsh/lib/alias.zsh"
  run audit
  [ "$status" -eq 1 ]
  assert_contains "$output" "'nosuchtool' is invoked by config"
}

# The base system this check accepts is macOS's: an alias for a tool only macOS
# ships, such as pbcopy, is a missing tool on Linux.
# bats test_tags=macos
@test "audit: every tool this repo's config invokes is installed by something" {
  AUDIT_DIR="$REPO" run audit
  assert_contains "$output" "every tool the config names is installed by something"
  refute_contains "$output" "is invoked by config/"
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
  echo "# key bindings" > "$FIX/config/zsh/lib/editor.zsh"
  echo "# window titles" > "$FIX/config/zsh/lib/terminal.zsh"
  run audit
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

# The fixtures above are miniatures, and a miniature cannot say what the repo's
# own libs are called. Regression: two libs arrived named for what they do, the
# audit took each name for a tool, and the weekly run was the first to notice.
@test "audit: every lib in this repo is a tool's or is named as not one" {
  AUDIT_DIR="$REPO" run audit
  assert_contains "$output" "every tool-specific lib has a package behind it"
  refute_contains "$output" "which no Brewfile entry installs"
}

@test "audit: a section that cannot run says so rather than passing quietly" {
  # No brew and no gh on PATH at all.
  run env -i HOME="$HOME" PATH="/usr/bin:/bin" bash -c "cd '$FIX' && ./script/audit"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  # Named, both of them: the fixture has no Neovim lockfile, so that section is
  # in this line whatever brew and gh are doing.
  echo "$output" | grep -q "NOT CHECKED: brew github" \
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
  # so an archived one would sit there untouched.
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

@test "audit: an archived tmux plugin fails too" {
  # tpm installs each plugin at whatever is newest and nothing pins them, so
  # they are the upstreams most worth watching, and they were the one set the
  # audit never asked about.
  mkdir -p "$FIX/config/tmux"
  printf "set -g @plugin 'someone/dead-tmux-plugin'\n" > "$FIX/config/tmux/tmux.conf"
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
  echo "$output" | grep -q "someone/dead-tmux-plugin is archived upstream" || { echo "$output"; return 1; }
}

@test "audit: a lockfile nobody has moved in six months warns" {
  # lazy.nvim never moves its own lockfile and no bot proposes to, so the pins
  # in it only get older. Homebrew's Neovim does not wait for them.
  given_lockfile_committed 2020-01-01
  run audit
  [ "$status" -eq 0 ] || { echo "an old lockfile is a warning, not a failure: $output"; return 1; }
  assert_contains "$output" "lazy-lock.json last changed 2020-01-01, over 6 months ago"
  assert_contains "$output" "0 failures, 1 warnings"
}

@test "audit: a lockfile that moved recently is one ok line" {
  given_lockfile_committed "$(date +%Y-%m-%d)"
  run audit
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "ok    config/nvim/lazy-lock.json last changed"
  assert_contains "$output" "0 failures, 0 warnings"
  refute_contains "$output" "nvim-lock" "the report"
}

@test "audit: a shallow clone does not vouch for the lockfile's age" {
  # A checkout of depth one has a single commit, which appears to have added
  # every file, so the lockfile would read as changed today for ever. That is
  # the clone a workflow gets unless it asks for the history.
  given_lockfile_committed 2020-01-01
  echo "later" > "$FIX/unrelated"
  fix_git add -A
  fix_git commit -qm "something else, today"
  local shallow="$BATS_TEST_TMPDIR/shallow"
  fix_git clone -q --depth 1 "file://$FIX" "$shallow"
  AUDIT_DIR="$shallow" run audit
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "not checked: this is not a clone with its full history"
  echo "$output" | grep -q "NOT CHECKED:.*nvim-lock" || { echo "$output"; return 1; }
  refute_contains "$output" "lazy-lock.json last changed" "the report"
}

@test "audit: a lockfile git has never seen is not given an age" {
  echo "tracked" > "$FIX/unrelated"
  fix_git init -q
  fix_git add unrelated
  fix_git commit -qm "everything but the lockfile"
  mkdir -p "$FIX/config/nvim"
  echo '{}' > "$FIX/config/nvim/lazy-lock.json"
  run audit
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "not checked: config/nvim/lazy-lock.json has never been committed"
  refute_contains "$output" "last changed" "the report"
}
