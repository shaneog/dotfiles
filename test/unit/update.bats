#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# script/update is the one script here that replaces itself while it runs, and
# the one most likely to be run long after anyone last read it. What is
# pinned here: the order of its steps, that a failed step stops the ones after
# it, that the pulled script is the one that finishes the run, and that it stays
# the part of bootstrap that asks for no password.
#
# The clone is a real one, of an upstream repository beside it, holding the real
# script/update. The scripts it calls are stand-ins that record that they ran.

setup() {
  UHOME="$BATS_TEST_TMPDIR/home"
  UPSTREAM="$BATS_TEST_TMPDIR/upstream"
  CLONE="$UHOME/.dotfiles"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  LOG="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$UHOME" "$UPSTREAM/script" "$STUBS"
  guard_home "$UHOME"
  : > "$LOG"

  cp "$REPO/script/update" "$UPSTREAM/script/update"
  local s
  for s in setup after-setup macos; do
    printf '#!/bin/sh\nprintf "%s %%s\\n" "$*" >> "$CALL_LOG"\n' "$s" > "$UPSTREAM/script/$s"
  done
  chmod +x "$UPSTREAM"/script/*
  echo "brew 'fzf'" > "$UPSTREAM/Brewfile"
  upstream_git init -q
  upstream_commit "fixture"
  upstream_git clone -q "$UPSTREAM" "$CLONE"

  # `bundle check` answers what BREW_CHECK says; everything is recorded.
  cat > "$STUBS/brew" <<'BREW'
#!/bin/sh
printf 'brew %s\n' "$*" >> "$CALL_LOG"
[ "$1 $2" = "bundle check" ] && exit "${BREW_CHECK:-0}"
exit 0
BREW
  printf '#!/bin/sh\nprintf "sudo %%s\\n" "$*" >> "$CALL_LOG"\n' > "$STUBS/sudo"
  chmod +x "$STUBS"/*
}

# git for the fixture, with nothing of the machine's own config: a signing key
# or a hook there is not the fixture's to trigger.
upstream_git() {
  env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    git -C "$UPSTREAM" -c user.name=t -c user.email=t@example.invalid \
    -c commit.gpgsign=false -c init.defaultBranch=main "$@"
}

upstream_commit() {  # message
  upstream_git add -A
  upstream_git commit -qm "$1"
}

# As a user with only the stubs and the base system on PATH, from somewhere
# that is not the clone.
update() {
  ( cd / && env -i HOME="$UHOME" PATH="$STUBS:/usr/bin:/bin" CALL_LOG="$LOG" \
      GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
      BREW_CHECK="${BREW_CHECK:-0}" "$CLONE/script/update" )
}

# A second clone at ~/.dotfiles-private, of a repository of its own.
make_private() {
  PRIVATE_UPSTREAM="$BATS_TEST_TMPDIR/private-upstream"
  mkdir -p "$PRIVATE_UPSTREAM"
  echo "# not for publishing" > "$PRIVATE_UPSTREAM/a-skill"
  private_git init -q
  private_git add -A
  private_git commit -qm "fixture"
  private_git clone -q "$PRIVATE_UPSTREAM" "$UHOME/.dotfiles-private"
}

private_git() {
  env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    git -C "$PRIVATE_UPSTREAM" -c user.name=t -c user.email=t@example.invalid \
    -c commit.gpgsign=false -c init.defaultBranch=main "$@"
}

# What ran, in order, without its arguments.
steps() { cut -d' ' -f1 "$LOG" | tr '\n' ',' ; }

@test "update: pulls, links, checks the Brewfile and restores Neovim, in that order" {
  echo "a new config" > "$UPSTREAM/newer"
  upstream_commit "newer"
  run update
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ -f "$CLONE/newer" ] || { echo "the pull brought nothing in: $output"; return 1; }
  assert_equal "$(steps)" "setup,brew,after-setup," "what ran, in order"
  assert_contains "$output" "Moved from"
  refute_contains "$output" "NOT DONE"
}

@test "update: with nothing new upstream, says so and still runs every step" {
  # A link somebody deleted, or a formula somebody removed, is put back by a run
  # that pulled nothing.
  run update
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "Nothing new upstream"
  assert_equal "$(steps)" "setup,brew,after-setup," "what ran, in order"
}

@test "update: the script that was pulled is the one that finishes the run" {
  # Otherwise a step added upstream does not run until the update after the one
  # that fetched it, and a machine is left half way between two versions.
  cat > "$UPSTREAM/script/update" <<'NEWER'
#!/bin/sh
echo "pulled-update from ${DOTFILES_UPDATE_FROM:-nowhere}" >> "$CALL_LOG"
NEWER
  upstream_commit "a different update"
  local before; before="$(git -C "$CLONE" rev-parse --short HEAD)"
  run update
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(cat "$LOG")" "pulled-update from $before" "what ran"
}

@test "update: stops when the pull fails" {
  git -C "$CLONE" remote set-url origin "$BATS_TEST_TMPDIR/no-such-repo"
  run update
  [ "$status" -ne 0 ] || { echo "a failed pull must fail the run: $output"; return 1; }
  assert_contains "$output" "The pull failed, so nothing was linked or installed"
  assert_equal "$(cat "$LOG")" "" "what ran after the pull failed"
}

@test "update: a link step that fails stops before anything is installed" {
  printf '#!/bin/sh\necho "setup" >> "$CALL_LOG"\nexit 1\n' > "$UPSTREAM/script/setup"
  upstream_commit "a setup that fails"
  run update
  [ "$status" -ne 0 ] || { echo "$output"; return 1; }
  assert_equal "$(steps)" "setup," "what ran, in order"
}

@test "update: installs from the Brewfile only when something in it is missing" {
  run update
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(grep -c '^brew bundle --file=' "$LOG")" "0" "installs when the check passed"

  : > "$LOG"
  BREW_CHECK=1 run update
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  # The clone as the script names it: with links resolved, which on a Mac puts
  # /private in front of a temporary directory.
  local brewfile; brewfile="$(cd "$CLONE" && pwd -P)/Brewfile"
  # --verbose: bundle otherwise keeps the install's output to itself until
  # everything is in, and a long install is then a terminal showing nothing.
  assert_equal "$(grep '^brew' "$LOG" | tr '\n' ',')" \
    "brew bundle check --file=$brewfile,brew bundle --file=$brewfile --verbose," \
    "what brew was asked, in order"
}

@test "update: without brew, says what was not done and carries on" {
  rm "$STUBS/brew"
  run update
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "NOT DONE: brewfile"
  assert_equal "$(steps)" "setup,after-setup," "what ran, in order"
}

@test "update: a private clone is pulled too, before anything is linked" {
  make_private
  echo "# newer" > "$PRIVATE_UPSTREAM/a-newer-skill"
  private_git add -A
  private_git commit -qm "newer"
  # A link step that says whether the newer file was there when it ran.
  cat > "$UPSTREAM/script/setup" <<'SETUP'
#!/bin/sh
if [ -f "$HOME/.dotfiles-private/a-newer-skill" ]; then
  echo "setup after-the-private-pull" >> "$CALL_LOG"
else
  echo "setup before-the-private-pull" >> "$CALL_LOG"
fi
SETUP
  upstream_commit "a setup that looks"
  run update
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$(cat "$LOG")" "setup after-the-private-pull" "what ran"
  refute_contains "$output" "NOT DONE"
}

@test "update: a private clone that cannot be pulled is said, and the run goes on" {
  # Its remote may want a sign-in this machine does not have. That is no
  # reason to leave the public half of the machine out of date.
  make_private
  git -C "$UHOME/.dotfiles-private" remote set-url origin "$BATS_TEST_TMPDIR/no-such-repo"
  run update
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "NOT DONE: private-clone"
  assert_equal "$(steps)" "setup,brew,after-setup," "what ran, in order"
}

@test "update: asks for no password and applies no macOS settings" {
  # That is bootstrap's half. An update that can stop on a password prompt is
  # one that cannot be left to run.
  BREW_CHECK=1 run update
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  refute_contains "$(cat "$LOG")" "sudo" "what ran"
  refute_contains "$(cat "$LOG")" "macos" "what ran"
}
