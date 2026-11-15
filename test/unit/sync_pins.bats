#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# sync_pins is what carries a changed pin to a machine that already has the
# plugin installed. Everything here is local: the "upstream" is a repository in
# the test's own directory, so nothing is fetched from the network.

setup() {
  ZHOME="$BATS_TEST_TMPDIR/zinit"
  UPSTREAM="$BATS_TEST_TMPDIR/upstream"
  PLUGIN="$ZHOME/plugins/some---plugin"
  mkdir -p "$ZHOME/plugins"

  plain_git init -q "$UPSTREAM"
  commit one; ONE="$(head_of "$UPSTREAM")"
  commit two; TWO="$(head_of "$UPSTREAM")"
  # Installed the way zinit leaves an unpinned plugin: on a branch, at its tip.
  plain_git clone -q "$UPSTREAM" "$PLUGIN"
}

# git with nobody's configuration. This repo's own git config signs every
# commit, and it is what $HOME holds wherever the dotfiles are installed.
plain_git() {
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git "$@"
}

commit() {
  plain_git -C "$UPSTREAM" -c user.name=tester -c user.email=tester@example.com \
    commit -q --allow-empty -m "$1"
}

head_of() { plain_git -C "$1" rev-parse HEAD; }

# sync_pins, with the pins given as "repo commit" pairs.
sync_pins() {
  env -i HOME="$BATS_TEST_TMPDIR" PATH="$PATH" "$ZSH_BIN" -fc "
    fpath=($REPO/config/zsh/autoload \$fpath)
    autoload -Uz sync_pins
    typeset -A ZINIT; ZINIT[ZINIT_HOME]='$ZHOME/zinit'
    typeset -gA DOTFILES_PINS=( $* )
    sync_pins"
}

@test "sync_pins moves a plugin installed at another commit to its pin" {
  run --separate-stderr sync_pins some/plugin "$ONE"
  [ "$status" -eq 0 ]
  assert_equal "$(head_of "$PLUGIN")" "$ONE" "the commit the plugin is at"
  assert_contains "$output" "Moving some/plugin"
  [ -z "$stderr" ] || { echo "stderr: $stderr"; return 1; }
}

@test "sync_pins says nothing and changes nothing once a plugin is at its pin" {
  sync_pins some/plugin "$ONE" >/dev/null
  run --separate-stderr sync_pins some/plugin "$ONE"
  [ "$status" -eq 0 ]
  [ -z "$output$stderr" ] || { echo "it spoke: $output$stderr"; return 1; }
  assert_equal "$(head_of "$PLUGIN")" "$ONE" "the commit the plugin is at"
}

@test "sync_pins fetches a pinned commit the install has not seen yet" {
  commit three; local three; three="$(head_of "$UPSTREAM")"
  run sync_pins some/plugin "$three"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(head_of "$PLUGIN")" "$three" "the commit the plugin is at"
}

@test "sync_pins moves zinit itself, which lives outside the plugin directory" {
  plain_git clone -q "$UPSTREAM" "$ZHOME/zinit"
  run sync_pins zdharma-continuum/zinit "$ONE"
  [ "$status" -eq 0 ]
  assert_equal "$(head_of "$ZHOME/zinit")" "$ONE" "the commit zinit is at"
}

@test "sync_pins leaves a plugin that is not installed for zinit to clone" {
  run --separate-stderr sync_pins other/plugin "$ONE"
  [ "$status" -eq 0 ]
  [ -z "$output$stderr" ] || { echo "it spoke: $output$stderr"; return 1; }
  [ ! -e "$ZHOME/plugins/other---plugin" ]
}

@test "sync_pins keeps the installed commit, and says so, when the pin cannot be fetched" {
  # No network, or a commit that upstream no longer has. A shell that starts
  # with yesterday's plugin beats one that does not start.
  local missing=0123456789abcdef0123456789abcdef01234567
  run --separate-stderr sync_pins some/plugin "$missing"
  [ "$status" -eq 0 ]
  assert_equal "$(head_of "$PLUGIN")" "$TWO" "the commit the plugin is at"
  assert_contains "$stderr" "Could not move some/plugin" "stderr"
}

@test "sync_pins deletes Prezto's modules when the pinned commit changes, and only those" {
  mkdir -p "$ZHOME/snippets/PZTM::editor" "$ZHOME/snippets/PZT::modules--helper" \
           "$ZHOME/snippets/OMZ::somebody-elses"
  echo "$ONE" > "$ZHOME/snippets/.prezto-commit"

  run sync_pins sorin-ionescu/prezto "$TWO"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(ls "$ZHOME/snippets")" "OMZ::somebody-elses" "the snippets left"
  assert_equal "$(cat "$ZHOME/snippets/.prezto-commit")" "$TWO" "the recorded commit"
}

@test "sync_pins removes the completions a deleted Prezto module leaves dangling, and no others" {
  # Regression: a module installed with its functions had them linked into
  # zinit's completions directory, and every compinit after the module was
  # deleted printed "no such file or directory" for each one.
  mkdir -p "$ZHOME/snippets/PZTM::git/functions" "$ZHOME/snippets/OMZ::somebody-elses" \
           "$ZHOME/completions"
  touch "$ZHOME/snippets/PZTM::git/functions/_git-info" "$ZHOME/snippets/OMZ::somebody-elses/_theirs"
  ln -s "$ZHOME/snippets/PZTM::git/functions/_git-info" "$ZHOME/completions/_git-info"
  ln -s "$ZHOME/snippets/OMZ::somebody-elses/_theirs" "$ZHOME/completions/_theirs"
  echo "$ONE" > "$ZHOME/snippets/.prezto-commit"

  run sync_pins sorin-ionescu/prezto "$TWO"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(ls "$ZHOME/completions")" "_theirs" "the completions left"
}

@test "sync_pins keeps Prezto's modules while the pinned commit is the one they came from" {
  mkdir -p "$ZHOME/snippets/PZTM::editor"
  echo "$ONE" > "$ZHOME/snippets/.prezto-commit"
  run sync_pins sorin-ionescu/prezto "$ONE"
  [ "$status" -eq 0 ]
  [ -d "$ZHOME/snippets/PZTM::editor" ] || { echo "the module was deleted"; return 1; }
}

@test "sync_pins records Prezto's commit on a machine with nothing installed" {
  # Otherwise the second shell would find no record, and delete what the
  # first one had just downloaded.
  rm -rf "$ZHOME"
  run sync_pins sorin-ionescu/prezto "$ONE"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(cat "$ZHOME/snippets/.prezto-commit")" "$ONE" "the recorded commit"
}
