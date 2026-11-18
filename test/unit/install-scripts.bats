#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# script/bootstrap and script/remove only ever run for real on a new machine or
# a disposable runner, and the parts tested here are the ones a runner cannot
# reach: it has passwordless sudo, so the askpass helper is never written, it
# always has a network, and it has neither Xcode nor anyone else's symlinks.
#
# Two ways in. Small helpers are lifted out of the script by name and called
# directly, so nothing else in the script runs. Whole-script runs get a PATH of
# stubs and a disposable $HOME, and sudo is a stub that records its arguments
# and runs nothing: these scripts hand it `rm -rf` and `chsh`.

setup() {
  IHOME="$BATS_TEST_TMPDIR/home"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  LOG="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$IHOME" "$STUBS"
  guard_home "$IHOME"
  : > "$LOG"

  printf '#!/bin/sh\nprintf "sudo %%s\\n" "$*" >> "$CALL_LOG"\n' > "$STUBS/sudo"
  printf '#!/bin/sh\nexit 0\n' > "$STUBS/caffeinate"
  printf '#!/bin/sh\necho "staff admin"\n' > "$STUBS/groups"
  # Present, so bootstrap never reaches for Homebrew's installer; and curl
  # refuses, so nothing could be fetched even if it did.
  printf '#!/bin/sh\nexit 0\n' > "$STUBS/brew"
  printf '#!/bin/sh\nexit 1\n' > "$STUBS/curl"
  printf '#!/bin/sh\necho "UserShell: /bin/zsh"\n' > "$STUBS/dscl"
  chmod +x "$STUBS"/*
}

# Define one function from a script in this shell, without running the script.
load_fn() {  # script, function
  local body
  body="$(sed -n "/^$2() {/,/^}/p" "$REPO/script/$1")"
  [ -n "$body" ] || { echo "no function $2 in script/$1"; return 1; }
  eval "$body"
}

# A whole script, as an admin user who is not root, seeing only the stubs and
# the base system.
run_script() {  # script, args...
  local script="$1"; shift
  local s
  for s in sudo brew curl; do
    [ -x "$STUBS/$s" ] || { echo "refusing to run $script without a $s stub"; return 1; }
  done
  _timeout 60 env -i HOME="$IHOME" USER=tester PATH="$STUBS:/usr/bin:/bin" \
    CALL_LOG="$LOG" ${DOTFILES_URL:+DOTFILES_URL="$DOTFILES_URL"} \
    bash "$REPO/script/$script" "$@"
}

@test "the askpass helper hands back the password exactly as it was typed" {
  # Regression: the helper was written with the password pasted between double
  # quotes, so `pa$$word` came back as `pa` followed by a process id, and a
  # password containing backticks ran what was between them.
  local script helper pw
  for script in bootstrap remove; do
    load_fn "$script" write_askpass
    helper="$BATS_TEST_TMPDIR/askpass-$script"
    while IFS= read -r pw; do
      write_askpass "$helper" "$pw"
      chmod 700 "$helper"
      run "$helper"
      [ "$status" -eq 0 ]
      assert_equal "$output" "$pw" "what script/$script's helper printed"
    done <<'PASSWORDS'
correct horse battery
pa$$word
he said "hi"
back\slash and 'quotes'
tick`touch "$HOME/expanded"`mark
$(touch "$HOME/expanded")
-n leading dash
  two  spaces
pässwörd
PASSWORDS
    [ ! -e "$HOME/expanded" ] || { echo "the helper ran part of a password"; return 1; }
  done
}

@test "the password beside the askpass helper is readable only by its owner" {
  local script helper
  for script in bootstrap remove; do
    load_fn "$script" write_askpass
    helper="$BATS_TEST_TMPDIR/askpass-$script"
    write_askpass "$helper" "secret"
    assert_equal "$(ls -l "$helper.secret" | cut -c1-10)" "-rw-------" \
      "the mode of script/$script's password file"
  done
}

@test "bootstrap stops when the dotfiles cannot be fetched" {
  # Regression: an unreachable URL skipped the clone without a word, and the
  # run went on to finish with "Your system is now bootstrapped!".
  DOTFILES_URL="$BATS_TEST_TMPDIR/no-such-repo" run run_script bootstrap
  [ "$status" -ne 0 ]
  assert_contains "$output" "Cannot reach $BATS_TEST_TMPDIR/no-such-repo"
  refute_contains "$output" "now bootstrapped"
  [ ! -e "$IHOME/.dotfiles" ]
}

# A repository bootstrap can clone, whose script/macos records that it ran. It
# reports something left to apply for as long as $HOME/settings-left exists,
# which stands for a new machine before the Brewfile is in.
#
# No Brewfile is linked, so bootstrap never runs `brew bundle`: on a Mac it
# puts the real Homebrew ahead of the stubs on PATH as soon as it finds one.
# The login shell step comes straight after the Brewfile, and dscl is what it
# asks first, so dscl marks the place instead.
make_dotfiles_fixture() {
  FIXTURE="$BATS_TEST_TMPDIR/dotfiles-fixture"
  mkdir -p "$FIXTURE/script"
  printf '#!/bin/sh\nexit 0\n' > "$FIXTURE/script/setup"
  cat > "$FIXTURE/script/macos" <<'MACOS'
#!/bin/sh
printf 'macos %s\n' "$*" >> "$CALL_LOG"
if [ "$1" = "--check" ] && [ -e "$HOME/settings-left" ]; then exit 1; fi
exit 0
MACOS
  # An app is waiting for its settings for as long as $HOME/apps-left exists.
  printf '#!/bin/sh\n[ "$1" = "--check" ] && [ ! -e "$HOME/apps-left" ]\n' > "$FIXTURE/script/apps"
  chmod +x "$FIXTURE/script/setup" "$FIXTURE/script/macos" "$FIXTURE/script/apps"
  local git=(env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    git -C "$FIXTURE" -c user.name=t -c user.email=t@example.invalid
    -c commit.gpgsign=false -c init.defaultBranch=main)
  "${git[@]}" init -q && "${git[@]}" add -A && "${git[@]}" commit -qm fixture
  printf '#!/bin/sh\necho "login shell step" >> "$CALL_LOG"\necho "UserShell: /bin/zsh"\n' > "$STUBS/dscl"
  chmod +x "$STUBS/dscl"
}

@test "bootstrap applies the macOS settings again once the Brewfile is in" {
  # Regression: script/macos ran once, before the Brewfile, so on a new machine
  # Touch ID for sudo did not work inside tmux until someone ran it by hand.
  make_dotfiles_fixture
  : > "$IHOME/settings-left"
  DOTFILES_URL="$FIXTURE" run run_script bootstrap
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(grep -E "^(macos|login shell)" "$LOG" | tr '\n' ',')" \
    "macos ,login shell step,macos --check,macos ," "what ran, in order"
}

@test "bootstrap leaves the macOS settings alone when its check is clean" {
  make_dotfiles_fixture
  DOTFILES_URL="$FIXTURE" run run_script bootstrap
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(grep -c "^macos $" "$LOG")" "1" "how many times the settings were applied"
  grep -q "^macos --check$" "$LOG" || { echo "the check never ran: $(cat "$LOG")"; return 1; }
}

@test "bootstrap ends by naming what is still missing, and only that" {
  # ~/.gitconfig-user and 1Password's agent are the two things no script here
  # can supply. Git says nothing at all when the first is absent.
  # An app with no settings is not one of those two, and waits on the same
  # thing they do, so it is named in the same place.
  make_dotfiles_fixture
  : > "$IHOME/apps-left"
  DOTFILES_URL="$FIXTURE" run run_script bootstrap
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "create ~/.gitconfig-user"
  assert_contains "$output" "make -C ~/.dotfiles identity"
  assert_contains "$output" "1Password's SSH agent"
  assert_contains "$output" "make -C ~/.dotfiles apps"

  # A socket's path has a short limit, and the test directory is already long,
  # so the home moves somewhere short for the half where both are present.
  local short; short="$(mktemp -d /tmp/dotfiles-b.XXXX)"
  guard_home "$short"
  local agent="$short/Library/Group Containers/2BUA8C4S2C.com.1password/t"
  mkdir -p "$agent"
  python3 -c "import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])" "$agent/agent.sock"
  : > "$short/.gitconfig-user"
  IHOME="$short" DOTFILES_URL="$FIXTURE" run run_script bootstrap
  rm -rf "$short"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "now bootstrapped"
  refute_contains "$output" "Still to do"
}

@test "remove takes the links into the clone and leaves other dangling links alone" {
  mkdir -p "$IHOME/.dotfiles/config/zsh" "$IHOME/.dotfiles/ssh" "$IHOME/elsewhere"
  mkdir -p "$IHOME/.config/some-other-tool" "$IHOME/.ssh"
  : > "$IHOME/.dotfiles/config/zsh/.zshenv"
  : > "$IHOME/.dotfiles/ssh/config"
  : > "$IHOME/.dotfiles/Brewfile"
  ln -s "$IHOME/.dotfiles/config/zsh" "$IHOME/.config/zsh"
  ln -s "$IHOME/.dotfiles/ssh/config" "$IHOME/.ssh/config"
  ln -s "$IHOME/.dotfiles/Brewfile" "$IHOME/.Brewfile"
  # Through .config rather than straight into the clone, as older installs have it.
  ln -s "$IHOME/.config/zsh/.zshenv" "$IHOME/.zshenv"
  ln -s "$IHOME/elsewhere" "$IHOME/.kept"
  # Already dangling before anything is removed: a share that is not mounted.
  ln -s "$BATS_TEST_TMPDIR/not-mounted/share" "$IHOME/nas"
  ln -s "$BATS_TEST_TMPDIR/not-mounted/tool" "$IHOME/.config/not-ours"
  echo "keep me" > "$IHOME/.config/some-other-tool/state"
  echo "example.com ssh-ed25519 AAAA" > "$IHOME/.ssh/known_hosts"

  run run_script remove <<< "y"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }

  [ ! -e "$IHOME/.dotfiles" ]
  local link
  for link in .zshenv .Brewfile .config/zsh .ssh/config; do
    [ ! -L "$IHOME/$link" ] || { echo "$link survived as a dangling link"; return 1; }
  done
  [ -L "$IHOME/.kept" ]             || { echo "a link to somewhere else was removed"; return 1; }
  [ -L "$IHOME/nas" ]               || { echo "someone else's dangling link was removed"; return 1; }
  [ -L "$IHOME/.config/not-ours" ]  || { echo "someone else's dangling link was removed"; return 1; }
  assert_equal "$(cat "$IHOME/.config/some-other-tool/state")" "keep me"
  assert_equal "$(cat "$IHOME/.ssh/known_hosts")" "example.com ssh-ed25519 AAAA"
}

@test "remove refuses while ~/.config or ~/.ssh is a link to the clone's whole directory" {
  # Regression: on a home laid out that way, removing the clone deleted every
  # other tool's configuration and ssh's known_hosts along with it.
  local dir
  for dir in config ssh; do
    rm -rf "$IHOME"; mkdir -p "$IHOME/.dotfiles/$dir"
    echo "keep me" > "$IHOME/.dotfiles/$dir/somebody-elses"
    ln -s "$IHOME/.dotfiles/$dir" "$IHOME/.$dir"

    run run_script remove <<< "y"
    [ "$status" -ne 0 ] || { echo "removed with ~/.$dir still a link into the clone"; return 1; }
    assert_contains "$output" "script/setup first"
    assert_equal "$(cat "$IHOME/.$dir/somebody-elses")" "keep me" "the file under ~/.$dir"
    # Nothing at all had been done by the time it stopped.
    refute_contains "$(cat "$LOG")" "dscl" "what was run with sudo"
  done
}

@test "remove only ever names the Command Line Tools for deletion" {
  load_fn remove command_line_tools_dir

  printf '#!/bin/sh\necho /Applications/Xcode.app/Contents/Developer\n' > "$STUBS/xcode-select"
  chmod +x "$STUBS/xcode-select"
  PATH="$STUBS:$PATH" run command_line_tools_dir
  [ "$status" -ne 0 ]
  [ -z "$output" ] || { echo "offered Xcode's own directory: $output"; return 1; }

  printf '#!/bin/sh\necho /Library/Developer/CommandLineTools\n' > "$STUBS/xcode-select"
  PATH="$STUBS:$PATH" run command_line_tools_dir
  [ "$status" -eq 0 ]
  assert_equal "$output" "/Library/Developer/CommandLineTools"

  # Nothing selected at all, which is how xcode-select answers on a machine
  # that has neither.
  printf '#!/bin/sh\necho "error: unable to get active developer directory" >&2\nexit 2\n' \
    > "$STUBS/xcode-select"
  PATH="$STUBS:$PATH" run command_line_tools_dir
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}
