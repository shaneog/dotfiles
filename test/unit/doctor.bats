#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# script/doctor reports on one machine, and its two ways of being wrong are the
# ones that get a report ignored: calling a broken machine healthy, and crying
# wolf on a healthy one. So each test starts from a machine that passes and
# spoils one thing.
#
# The machine is a disposable home with a clone in it, linked by the real
# script/setup, so "intact" here means whatever setup actually produces. The
# clone has a bare origin beside it. script/brew-drift is the real one too, over
# a stub brew: doctor reads its report, and a stand-in report would go on
# passing after the real one changed shape.

setup() {
  # Short, and not under the test directory: a socket's path has a low limit,
  # and the one 1Password's agent uses is long before the home is added.
  DHOME="$(mktemp -d /tmp/dotfiles-d.XXXXXX)"
  guard_home "$DHOME"
  FIX="$DHOME/.dotfiles"
  ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  BREW_STATE="$BATS_TEST_TMPDIR/brew"
  mkdir -p "$FIX/script" "$FIX/config/zsh" "$FIX/config/nvim" "$FIX/ssh" "$STUBS" "$BREW_STATE"

  cp "$REPO/script/doctor" "$REPO/script/setup" "$REPO/script/brew-drift" "$FIX/script/"
  echo "# ours" > "$FIX/config/zsh/.zshenv"
  echo "-- ours" > "$FIX/config/nvim/init.lua"
  echo "# ours" > "$FIX/config/starship.toml"
  echo "# ours" > "$FIX/ssh/config"
  printf "brew 'fzf'\ncask '1password'\n" > "$FIX/Brewfile"
  printf '#!/bin/sh\necho "33 of 33 settings applied, 0 not"\n' > "$FIX/script/macos"
  chmod +x "$FIX/script/macos"

  fix_git init -q
  fix_git add -A
  fix_git commit -qm "fixture"
  fix_git init -q --bare "$ORIGIN"
  fix_git remote add origin "$ORIGIN"
  fix_git push -q origin main

  # Everything a healthy machine has.
  ( cd "$FIX" && HOME="$DHOME" ./script/setup ) >/dev/null 2>&1
  : > "$DHOME/.gitconfig-user"
  AGENT="$DHOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  mkdir -p "$(dirname "$AGENT")"
  python3 -c "import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])" "$AGENT"
  mkdir -p "$DHOME/.local/state/dotfiles"
  date +%Y-%m-%d > "$DHOME/.local/state/dotfiles/vm-last-run"

  # brew answers from three files, which a test rewrites to spoil one thing.
  cat > "$STUBS/brew" <<'BREW'
#!/bin/sh
case "$1 $2 $3" in
  "info --json=v2 --installed") cat "$BREW_STATE/requested.json" ;;
esac
case "$1 $2" in
  "list --formula") cat "$BREW_STATE/formulae" ;;
  "list --cask")    cat "$BREW_STATE/casks" ;;
esac
exit 0
BREW
  given_requested fzf
  echo "fzf" > "$BREW_STATE/formulae"
  echo "1password" > "$BREW_STATE/casks"
  # Present, which is all doctor asks of either.
  printf '#!/bin/sh\nexit 0\n' > "$STUBS/defaults"
  printf '#!/bin/sh\nexit 0\n' > "$STUBS/tart"
  chmod +x "$STUBS"/*
}

teardown() {
  if [ -n "${DHOME:-}" ] && guard_home "$DHOME"; then
    rm -rf "$DHOME"
  fi
  return 0
}

# git for the fixture, with nothing of the machine's own config: a signing key
# or a hook there is not the fixture's to trigger.
fix_git() {
  env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    git -C "$FIX" -c user.name=t -c user.email=t@example.invalid \
    -c commit.gpgsign=false -c init.defaultBranch=main "$@"
}

# What brew says was installed by name, as opposed to pulled in by something.
given_requested() {  # formula...
  local name sep=""
  {
    printf '{"formulae":['
    for name in "$@"; do
      printf '%s{"name":"%s","desc":"a tool","installed":[{"installed_on_request":true}]}' "$sep" "$name"
      sep=","
    done
    printf '],"casks":[]}\n'
  } > "$BREW_STATE/requested.json"
}

# A commit on origin/main that the clone has not seen.
given_origin_moved() {
  local other="$BATS_TEST_TMPDIR/other"
  fix_git clone -q "$ORIGIN" "$other"
  echo "newer" > "$other/newer"
  FIX="$other" fix_git add -A
  FIX="$other" fix_git commit -qm "newer"
  FIX="$other" fix_git push -q origin main
  ORIGIN_HEAD="$(FIX="$other" fix_git rev-parse --short=7 HEAD)"
}

doctor() {
  ( cd / && HOME="$DHOME" PATH="$STUBS:$PATH" BREW_STATE="$BREW_STATE" \
      XDG_STATE_HOME="" VM_STAMP="" "$FIX/script/doctor" )
}

# The stubs and the base tools doctor calls, and nothing else: for the test
# that takes commands away, whatever this machine has in /usr/bin.
bare_path() {
  local dir="$BATS_TEST_TMPDIR/base" tool
  mkdir -p "$dir"
  for tool in bash git awk sed cut sort date ls cat tail grep dirname; do
    ln -sf "$(command -v "$tool")" "$dir/$tool"
  done
  echo "$STUBS:$dir"
}

# Every path under the home, links with where they point. A fetch would add
# files under .git, and a repair would change a link.
snapshot() {
  local f
  find "$DHOME" | sort | while IFS= read -r f; do
    if [ -L "$f" ]; then echo "$f -> $(readlink "$f")"; else echo "$f"; fi
  done
}

@test "doctor: a healthy machine passes, with nothing skipped" {
  run doctor
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "all 6 links point into the clone"
  assert_contains "$output" "level with origin/main"
  assert_contains "$output" "33 of 33 settings applied"
  assert_contains "$output" "everything the Brewfile declares is installed"
  assert_contains "$output" "the VM tier passed"
  assert_contains "$output" "0 failures, 0 warnings"
  refute_contains "$output" "NOT CHECKED"
}

@test "doctor: changes nothing, even with something to report" {
  given_origin_moved
  rm "$DHOME/.config/nvim" "$DHOME/.gitconfig-user"
  local before; before="$(snapshot)"
  run doctor
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_equal "$(snapshot)" "$before" "the home and the clone afterwards"
}

@test "doctor: a link that is gone, or points somewhere else, fails" {
  rm "$DHOME/.config/nvim"
  mkdir "$DHOME/.config/nvim"
  rm "$DHOME/.zshenv"
  ln -s "$DHOME/.gitconfig-user" "$DHOME/.zshenv"
  run doctor
  [ "$status" -eq 1 ] || { echo "broken links must fail the run: $output"; return 1; }
  assert_contains "$output" "FAIL  ~/.config/nvim is not a link to config/nvim: script/setup"
  assert_contains "$output" "FAIL  ~/.zshenv is not a link to config/zsh/.zshenv: script/setup"
  assert_contains "$output" "2 failures"
  refute_contains "$output" "links point into the clone"
}

@test "doctor: a config that was pulled and never linked fails" {
  # What a machine looks like after `git pull` on its own: the new entry is in
  # the clone, and nothing in ~/.config leads to it.
  mkdir "$FIX/config/newtool"
  echo "# ours" > "$FIX/config/newtool/settings"
  fix_git add -A
  run doctor
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "FAIL  ~/.config/newtool is not a link to config/newtool"
}

@test "doctor: a home still linked to the clone's whole directory is one failure" {
  # Every entry resolves through such a link, so each would pass -ef and fail
  # -L. One line that says what is wrong beats one line an entry that does not.
  rm -rf "$DHOME/.config"
  ln -s "$FIX/config" "$DHOME/.config"
  run doctor
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "FAIL  ~/.config is a link to the whole of config/"
  assert_contains "$output" "1 failures"
  refute_contains "$output" "~/.config/nvim is not a link"
}

@test "doctor: an ssh directory that holds a private key is not called broken" {
  # script/setup links nothing into one, so nothing is missing from it.
  rm "$DHOME/.ssh/config"
  : > "$DHOME/.ssh/id_ed25519"
  run doctor
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "~/.ssh holds a private key and is managed elsewhere"
  assert_contains "$output" "0 failures"
}

@test "doctor: a clone behind origin/main warns, without fetching" {
  given_origin_moved
  run doctor
  [ "$status" -eq 0 ] || { echo "being behind is a warning, not a failure: $output"; return 1; }
  assert_contains "$output" "behind origin/main, which has moved to $ORIGIN_HEAD: make update"
  assert_contains "$output" "0 failures, 1 warnings"
  [ ! -e "$FIX/.git/FETCH_HEAD" ] || { echo "doctor fetched"; return 1; }
}

@test "doctor: a clone that has fetched and not merged says how far behind" {
  given_origin_moved
  fix_git fetch -q origin
  run doctor
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "behind origin/main by 1: make update"
}

@test "doctor: a commit that was never pushed warns" {
  echo "local" > "$FIX/local"
  fix_git add -A
  fix_git commit -qm "local"
  run doctor
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "ahead of origin/main by 1"
  refute_contains "$output" "behind origin/main"
}

@test "doctor: a machine with no ~/.gitconfig-user fails" {
  # Git ignores a missing include without a word, so commits stop being signed
  # and nothing else reports it.
  rm "$DHOME/.gitconfig-user"
  run doctor
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "FAIL  ~/.gitconfig-user is missing"
}

@test "doctor: a machine without 1Password's agent socket fails" {
  # A file of the right name is not an agent.
  rm "$AGENT"
  : > "$AGENT"
  run doctor
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "FAIL  1Password's SSH agent has no socket"
}

@test "doctor: macOS settings that have drifted are reported, and counted" {
  # The counting half matters too: `warn` inside a piped while-loop increments
  # in a subshell, so the summary would say 0 warnings beneath two of them.
  cat > "$FIX/script/macos" <<'MACOS'
#!/bin/sh
echo "  not applied: com.apple.dock tilesize is 48, wanted 32 (icon size)"
echo "  not applied: pam sudo_local is unset, wanted authsufficientpam_tid.so (Touch ID)"
echo "31 of 33 settings applied, 2 not"
exit 1
MACOS
  run doctor
  [ "$status" -eq 0 ] || { echo "drift is a warning, not a failure: $output"; return 1; }
  assert_contains "$output" "warn  com.apple.dock tilesize"
  assert_contains "$output" "warn  pam sudo_local is unset"
  assert_contains "$output" "0 failures, 3 warnings"
}

@test "doctor: what the Brewfile declares and this machine lacks warns, by name" {
  : > "$BREW_STATE/formulae"
  : > "$BREW_STATE/casks"
  given_requested
  run doctor
  [ "$status" -eq 0 ] || { echo "a missing package is a warning: $output"; return 1; }
  assert_contains "$output" "warn  fzf is in the Brewfile and not installed: make update"
  assert_contains "$output" "warn  cask 1password is in the Brewfile and not installed: make update"
  assert_contains "$output" "0 failures, 2 warnings"
  refute_contains "$output" "everything the Brewfile declares is installed"
}

@test "doctor: what this machine has beyond the Brewfile is counted, not warned about" {
  # On a machine something else provisions, most of that list is not ours, and
  # a warning that is always there is one nobody reads.
  given_requested fzf entr watch
  printf 'fzf\nentr\nwatch\n' > "$BREW_STATE/formulae"
  run doctor
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "note  2 installed on request that the Brewfile does not declare: make brew-drift"
  assert_contains "$output" "0 failures, 0 warnings"
}

@test "doctor: a VM tier that has not run in a month warns" {
  echo "2020-01-01" > "$DHOME/.local/state/dotfiles/vm-last-run"
  run doctor
  [ "$status" -eq 0 ] || { echo "staleness is a warning, not a failure: $output"; return 1; }
  assert_contains "$output" "last passed 2020-01-01, over 30 days ago"
}

@test "doctor: a VM tier that has never run warns, where it could" {
  rm "$DHOME/.local/state/dotfiles/vm-last-run"
  run doctor
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "warn  the VM tier has no recorded run"
}

@test "doctor: a section that cannot run says so rather than passing quietly" {
  # No brew, no defaults and no tart, an origin that does not answer, and a
  # machine that has never run the VM tier. None of that is this machine being
  # broken, and none of it is this machine being fine.
  rm "$STUBS/brew" "$STUBS/defaults" "$STUBS/tart" "$DHOME/.local/state/dotfiles/vm-last-run"
  fix_git remote set-url origin "$BATS_TEST_TMPDIR/no-such-repo"
  local path; path="$(bare_path)"
  run env -i HOME="$DHOME" PATH="$path" "$FIX/script/doctor"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "NOT CHECKED: clone macos homebrew vm-tier"
  assert_contains "$output" "0 failures, 0 warnings"
  refute_contains "$output" "level with origin/main"
  refute_contains "$output" "settings applied"
  refute_contains "$output" "everything the Brewfile declares"
}

@test "doctor: a brew-drift that could not finish is not read as no drift" {
  printf '#!/bin/sh\necho "brew is not installed; nothing to compare"\n' > "$FIX/script/brew-drift"
  run doctor
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  echo "$output" | grep -q "NOT CHECKED:.*homebrew" || { echo "$output"; return 1; }
  refute_contains "$output" "everything the Brewfile declares"
}
