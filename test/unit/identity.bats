#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# script/identity writes the file git signs with, from an item in 1Password. Its
# ways of being wrong are worse than not having it: a file that is half there,
# so git reads a name and no key; an existing file replaced without being
# asked; and a private key on disk, on machines where none is ever meant to be.
#
# op is a stand-in that answers one field at a time from a directory, in the
# shape `op item get --fields label=... --format json` answers, and refuses the
# way the real one does when OP_REFUSES names a reason. It cannot say whether
# the real op still answers in that shape: that is checked on a Mac, by running
# the script.

setup() {
  IHOME="$BATS_TEST_TMPDIR/home"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  FIELDS="$BATS_TEST_TMPDIR/fields"
  LOG="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$IHOME" "$STUBS" "$FIELDS"
  guard_home "$IHOME"
  : > "$LOG"

  cat > "$STUBS/op" <<'OP'
#!/bin/sh
printf 'op %s\n' "$*" >> "$CALL_LOG"
[ "$1 $2" = "item get" ] || exit 2
item="$3"
label="${5#label=}"
case "${OP_REFUSES:-}" in
  signed-out) echo "[ERROR] 2026/01/01 00:00:00 account is not signed in" >&2; exit 1 ;;
  no-item)    echo "[ERROR] 2026/01/01 00:00:00 \"$item\" isn't an item. Specify the item with its UUID, name, or domain." >&2; exit 1 ;;
esac
[ "$item" = "${OP_HOLDS:-Git identity}" ] \
  || { echo "[ERROR] 2026/01/01 00:00:00 \"$item\" isn't an item." >&2; exit 1; }
[ -f "$OP_FIELDS/$label" ] \
  || { echo "[ERROR] 2026/01/01 00:00:00 \"$label\" isn't a field in the \"$item\" item" >&2; exit 1; }
[ "$label" != "${OP_DIES_AT:-}" ] || { echo "[ERROR] connection reset" >&2; exit 1; }
jq -n --arg label "$label" --rawfile value "$OP_FIELDS/$label" \
  '{id: "abc", type: "STRING", label: $label, value: ($value | rtrimstr("\n"))}'
OP
  chmod +x "$STUBS/op"

  KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFixtureKeyFixtureKeyFixtureKeyFixtureKeyAbCd"
  echo "Ada Example" > "$FIELDS/name"
  echo "ada@example.invalid" > "$FIELDS/email"
  echo "$KEY" > "$FIELDS/signingkey"
}

# As a user with the stand-in op, and jq and git from wherever this machine
# keeps them, started from somewhere that is not the clone.
identity() {
  ( cd / && env -i HOME="$IHOME" PATH="$STUBS:$PATH" CALL_LOG="$LOG" OP_FIELDS="$FIELDS" \
      GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
      OP_REFUSES="${OP_REFUSES:-}" OP_HOLDS="${OP_HOLDS:-}" OP_DIES_AT="${OP_DIES_AT:-}" \
      DOTFILES_IDENTITY_ITEM="${DOTFILES_IDENTITY_ITEM:-}" "$REPO/script/identity" "$@" )
}

# What git reads from the file, which is the only reader it has.
reads() {  # key
  git config --file "$IHOME/.gitconfig-user" --get "$1"
}

# Nothing of ours in the home but what the test put there: no file, and no
# scratch copy beside where it would be.
assert_nothing_written() {
  assert_equal "$(ls -A "$IHOME" | tr '\n' ' ')" "${1:-}" "what is in the home directory"
}

@test "identity: writes the three values git signs with" {
  run identity
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(reads user.name)" "Ada Example" "user.name"
  assert_equal "$(reads user.email)" "ada@example.invalid" "user.email"
  assert_equal "$(reads user.signingkey)" "$KEY" "user.signingkey"
  assert_contains "$output" "Wrote ~/.gitconfig-user from \"Git identity\""
  assert_nothing_written ".gitconfig-user "
}

@test "identity: the item comes from the argument, then the variable, then the default" {
  OP_HOLDS="Somewhere else" run identity
  [ "$status" -eq 1 ] || { echo "the default item is not there to find: $output"; return 1; }
  OP_HOLDS="Somewhere else" DOTFILES_IDENTITY_ITEM="Somewhere else" run identity
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  rm "$IHOME/.gitconfig-user"
  OP_HOLDS="A third" DOTFILES_IDENTITY_ITEM="Somewhere else" run identity "A third"
  [ "$status" -eq 0 ] || { echo "an argument outranks the variable: $output"; return 1; }
  assert_contains "$output" "from \"A third\""
}

@test "identity: a name git's format would misread is still the name git reads back" {
  # A semicolon starts a comment in a git config file, and a quote opens a
  # string. Written as text, this name would come back as its first two words.
  echo 'Ada "Countess" Example; of Lovelace # really' > "$FIELDS/name"
  run identity
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(reads user.name)" 'Ada "Countess" Example; of Lovelace # really' "user.name"
}

@test "identity: a file that is already there is left alone, and op is not asked" {
  printf '[user]\n\tname = Kept\n' > "$IHOME/.gitconfig-user"
  run identity
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(reads user.name)" "Kept" "user.name"
  assert_contains "$output" "script/identity --replace"
  assert_equal "$(cat "$LOG")" "" "what op was asked"
}

@test "identity: --replace changes the three values and keeps the rest of the file" {
  # The file is the machine's own, and may hold more than an identity: a
  # rewrite rule, an editor. Those are not 1Password's to drop.
  printf '[user]\n\tname = Old\n\tsigningkey = old-key\n[core]\n\teditor = ed\n' > "$IHOME/.gitconfig-user"
  run identity --replace
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(reads user.name)" "Ada Example" "user.name"
  assert_equal "$(reads user.email)" "ada@example.invalid" "user.email"
  assert_equal "$(reads user.signingkey)" "$KEY" "user.signingkey"
  assert_equal "$(reads core.editor)" "ed" "core.editor"
}

@test "identity: signed out of 1Password, it says so and writes nothing" {
  OP_REFUSES=signed-out run identity
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "account is not signed in"
  assert_contains "$output" "Integrate with 1Password CLI"
  assert_contains "$output" "signingkey = ssh-ed25519 AAAA..."
  assert_nothing_written
}

@test "identity: with no such item, it names the item and writes nothing" {
  OP_REFUSES=no-item run identity "Not there"
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "\"Not there\" isn't an item"
  assert_contains "$output" "by hand"
  assert_nothing_written
}

@test "identity: without op it explains, and writes nothing" {
  rm "$STUBS/op"
  local dir="$BATS_TEST_TMPDIR/base" tool
  mkdir -p "$dir"
  for tool in bash cat jq git; do ln -s "$(command -v "$tool")" "$dir/$tool"; done
  run env -i HOME="$IHOME" PATH="$dir" "$REPO/script/identity"
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "op, is not installed"
  assert_contains "$output" "by hand"
  assert_nothing_written
}

@test "identity: a read that fails partway leaves the old file as it was" {
  # The name and the email arrive and the key does not. A file written as the
  # answers came in would now hold a name git accepts and no key to sign with.
  printf '[user]\n\tname = Old\n\tsigningkey = old-key\n' > "$IHOME/.gitconfig-user"
  local before; before="$(cat "$IHOME/.gitconfig-user")"
  rm "$FIELDS/signingkey"
  run identity --replace
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "\"signingkey\" isn't a field"
  assert_equal "$(cat "$IHOME/.gitconfig-user")" "$before" "the file afterwards"
  assert_nothing_written ".gitconfig-user "
}

@test "identity: a write that fails partway leaves the old file whole, and no scratch file" {
  # git writes the name and the email and then cannot write the key. Written
  # in place, the file would now be the half that git accepts without a word.
  printf '[user]\n\tname = Old\n\tsigningkey = old-key\n' > "$IHOME/.gitconfig-user"
  local before; before="$(cat "$IHOME/.gitconfig-user")"
  cat > "$STUBS/git" <<GIT
#!/bin/sh
case "\$*" in *user.signingkey*) exit 1 ;; esac
exec "$(command -v git)" "\$@"
GIT
  chmod +x "$STUBS/git"
  run identity --replace
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "Could not write"
  assert_equal "$(cat "$IHOME/.gitconfig-user")" "$before" "the file afterwards"
  assert_nothing_written ".gitconfig-user "
}

@test "identity: a private key is refused, and never reaches the disk" {
  printf '%s\n' "-----BEGIN OPENSSH PRIVATE KEY-----" "b3BlbnNzaC1rZXktdjEAAAAA" \
    "-----END OPENSSH PRIVATE KEY-----" > "$FIELDS/signingkey"
  run identity
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "holds a private key"
  refute_contains "$output" "b3BlbnNzaC1rZXktdjEAAAAA"
  assert_nothing_written
}

@test "identity: a signing key that is not a public key is refused" {
  # A path, which is what the field's name suggests to anyone who has set
  # user.signingkey for GPG or for an ssh key on disk.
  echo "~/.ssh/id_ed25519.pub" > "$FIELDS/signingkey"
  run identity
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "is not a public key"
  assert_nothing_written
}

@test "identity: a value of more than one line is refused" {
  # A second line would be a second line of the config file, and could set
  # anything.
  printf 'Ada Example\n[core]\n' > "$FIELDS/name"
  run identity
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "name field"
  assert_nothing_written
}

@test "identity: an option it does not know is refused before anything is read" {
  run identity --force
  [ "$status" -eq 2 ] || { echo "$output"; return 1; }
  assert_contains "$output" "usage: script/identity"
  assert_equal "$(cat "$LOG")" "" "what op was asked"
}
