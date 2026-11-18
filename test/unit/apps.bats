#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# script/apps moves app settings between Macs through a document in 1Password.
# Its ways of being wrong all cost somebody their settings: writing over an app
# that was already set up, importing beneath a running app that then writes its
# own back, storing an archive that has lost the apps this Mac does not have,
# and leaving a copy of everything in a temporary directory.
#
# defaults, op, pgrep and open are stand-ins. defaults keeps one file per
# domain, and what is in it is whatever the test put there: the script never
# looks inside. op keeps documents in a directory, and answers in the shape
# `op item list --format json` answers. Neither can say whether the real one
# still behaves that way, or whether an app reads what was imported for it:
# that is checked on a Mac, by running the script.

setup() {
  AHOME="$BATS_TEST_TMPDIR/home"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  PREFS="$BATS_TEST_TMPDIR/prefs"
  OP_STORE="$BATS_TEST_TMPDIR/1password"
  APPS="$BATS_TEST_TMPDIR/Applications"
  OPENED="$BATS_TEST_TMPDIR/opened"
  TMP="$BATS_TEST_TMPDIR/tmp"
  LOG="$BATS_TEST_TMPDIR/calls"
  RUNNING="$BATS_TEST_TMPDIR/running"
  INPUT="$BATS_TEST_TMPDIR/typed"
  mkdir -p "$AHOME" "$STUBS" "$PREFS" "$OP_STORE" "$OPENED" "$TMP" \
    "$APPS/Rectangle.app" "$APPS/iStat Menus.app"
  guard_home "$AHOME"
  : > "$LOG"
  : > "$RUNNING"
  : > "$INPUT"

  cat > "$STUBS/defaults" <<'DEFAULTS'
#!/bin/sh
printf 'defaults %s\n' "$*" >> "$CALL_LOG"
case "$1" in
  read)   [ -f "$PREFS/$2.plist" ] ;;
  export) [ -f "$PREFS/$2.plist" ] && cat "$PREFS/$2.plist" > "$3" ;;
  import) [ "$2" != "${DEFAULTS_REFUSES:-}" ] && cat "$3" > "$PREFS/$2.plist" ;;
  *)      exit 2 ;;
esac
DEFAULTS

  cat > "$STUBS/op" <<'OP'
#!/bin/sh
printf 'op %s\n' "$*" >> "$CALL_LOG"
[ "${OP_REFUSES:-}" != "signed-out" ] \
  || { echo "[ERROR] 2026/01/01 00:00:00 account is not signed in" >&2; exit 1; }
case "$1 $2" in
  "item list")
    [ "$3 $4 $5 $6" = "--categories Document --format json" ] || exit 2
    printf '['
    sep=""
    for title in "$OP_STORE"/*/title; do
      [ -f "$title" ] || continue
      printf '%s' "$sep"
      jq -n --arg id "$(basename "$(dirname "$title")")" --rawfile title "$title" \
        '{id: $id, title: ($title | rtrimstr("\n")), category: "DOCUMENT"}'
      sep=","
    done
    printf ']\n' ;;
  "document get")
    [ "$4" = "--out-file" ] || exit 2
    [ -f "$OP_STORE/$3/file" ] || { echo "[ERROR] \"$3\" isn't an item." >&2; exit 1; }
    cat "$OP_STORE/$3/file" > "$5" ;;
  "document edit")
    [ "${OP_REFUSES:-}" != "write" ] || { echo "[ERROR] connection reset" >&2; exit 1; }
    [ -d "$OP_STORE/$3" ] || { echo "[ERROR] \"$3\" isn't an item." >&2; exit 1; }
    cat "$4" > "$OP_STORE/$3/file" ;;
  "document create")
    [ "$4" = "--title" ] || exit 2
    [ "${OP_REFUSES:-}" != "write" ] || { echo "[ERROR] connection reset" >&2; exit 1; }
    id="doc$(ls "$OP_STORE" | wc -l | tr -d ' ')"
    mkdir "$OP_STORE/$id"
    printf '%s\n' "$5" > "$OP_STORE/$id/title"
    cat "$3" > "$OP_STORE/$id/file" ;;
  *) exit 2 ;;
esac
OP

  # Running is whatever the test wrote down as running.
  printf '#!/bin/sh\n[ "$1" = "-f" ] && grep -qxF -- "$2" "$RUNNING_LIST"\n' > "$STUBS/pgrep"

  # Keeps a copy of any file it is handed, taken at the moment it is handed
  # it: that the file was there then is the thing to know.
  cat > "$STUBS/open" <<'OPEN'
#!/bin/sh
printf 'open %s\n' "$*" >> "$CALL_LOG"
[ "$1" = "-a" ] && [ -n "${3:-}" ] && cat "$3" > "$OPENED/$(basename "$3")"
exit 0
OPEN
  chmod +x "$STUBS"/*
}

# As a user with the stand-ins, started from somewhere that is not the clone.
# Whatever is in $INPUT is what gets typed; PERSON=1 is somebody at a keyboard.
apps() {
  ( cd / && env -i HOME="$AHOME" PATH="$STUBS:$PATH" TMPDIR="$TMP" CALL_LOG="$LOG" \
      PREFS="$PREFS" OP_STORE="$OP_STORE" OPENED="$OPENED" RUNNING_LIST="$RUNNING" \
      APPS_DIR="$APPS" APPS_ASK="${PERSON:-}" OP_REFUSES="${OP_REFUSES:-}" \
      DEFAULTS_REFUSES="${DEFAULTS_REFUSES:-}" \
      DOTFILES_APPS_ITEM="${DOTFILES_APPS_ITEM:-}" "$REPO/script/apps" "$@" < "$INPUT" )
}

# A document in 1Password holding these files, each given as path=content.
given_stored() {  # title, path=content...
  local title="$1" entry tree="$BATS_TEST_TMPDIR/tree.$RANDOM"
  shift
  mkdir -p "$tree"
  for entry in "$@"; do
    mkdir -p "$tree/$(dirname "${entry%%=*}")"
    printf '%s\n' "${entry#*=}" > "$tree/${entry%%=*}"
  done
  local id="doc$(ls "$OP_STORE" | wc -l | tr -d ' ')"
  mkdir "$OP_STORE/$id"
  echo "$title" > "$OP_STORE/$id/title"
  tar -czf "$OP_STORE/$id/file" -C "$tree" .
}

given_settings() {  # domain, content
  printf '%s\n' "$2" > "$PREFS/$1.plist"
}

# One file out of what a document holds now.
stored() {  # document id, path
  local out="$BATS_TEST_TMPDIR/unpacked.$RANDOM"
  mkdir -p "$out"
  tar -xzf "$OP_STORE/$1/file" -C "$out" || return 1
  cat "$out/$2"
}

# The whole point of a scratch directory that is removed: what was in it is
# every app's settings, licence and all.
assert_no_scratch() {
  assert_equal "$(ls -A "$TMP")" "" "what is left in the temporary directory"
}

RECT="com.knollsoft.Rectangle"
ISTAT="com.bjango.istatmenus.menubar.7"

# ------------------------------------------------------------------------ check

@test "apps: --check names an installed app with no settings, and asks 1Password nothing" {
  given_settings "$RECT" "set up"
  run apps --check
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "iStat Menus: no settings yet"
  assert_contains "$output" "Rectangle: has settings"
  refute_contains "$(cat "$LOG")" "op "

  given_settings "$ISTAT" "set up"
  run apps --check
  [ "$status" -eq 0 ] || { echo "every app has settings: $output"; return 1; }
}

@test "apps: --check says nothing of an app that is not installed" {
  rm -r "$APPS/iStat Menus.app"
  given_settings "$RECT" "set up"
  run apps --check
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  refute_contains "$output" "iStat Menus"
}

# ---------------------------------------------------------------------- restore

@test "apps: an app with no settings is given the stored ones" {
  given_stored "Mac app settings" "rectangle/$RECT.plist=from the old Mac"
  run apps rectangle
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(cat "$PREFS/$RECT.plist")" "from the old Mac" "Rectangle's settings"
  assert_contains "$output" "Rectangle: settings restored"
  assert_contains "$output" "Rectangle: by hand: Tick Rectangle under Accessibility"
  assert_no_scratch
}

@test "apps: an app that already has settings is left alone, and 1Password is not asked" {
  given_stored "Mac app settings" "rectangle/$RECT.plist=from the old Mac"
  given_settings "$RECT" "set up here"
  run apps rectangle
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(cat "$PREFS/$RECT.plist")" "set up here" "Rectangle's settings"
  assert_contains "$output" "left alone"
  assert_contains "$output" "script/apps --replace rectangle"
  refute_contains "$(cat "$LOG")" "op "
  refute_contains "$output" "by hand"
}

@test "apps: --replace replaces them, and keeps what was there" {
  given_stored "Mac app settings" "rectangle/$RECT.plist=from the old Mac"
  given_settings "$RECT" "set up here"
  run apps --replace rectangle
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(cat "$PREFS/$RECT.plist")" "from the old Mac" "Rectangle's settings"
  assert_equal "$(cat "$AHOME/.local/share/dotfiles/apps/$RECT.plist")" "set up here" "the copy of what it had"
  assert_contains "$output" "what it had is in ~/.local/share/dotfiles/apps"
}

@test "apps: nothing is imported beneath an app that is running" {
  given_stored "Mac app settings" "rectangle/$RECT.plist=from the old Mac"
  echo "Rectangle.app" > "$RUNNING"
  run apps rectangle
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "Rectangle: it is running"
  [ ! -e "$PREFS/$RECT.plist" ] || { echo "imported anyway: $(cat "$PREFS/$RECT.plist")"; return 1; }
}

@test "apps: an app that is not installed is passed over" {
  rm -r "$APPS/Rectangle.app"
  given_stored "Mac app settings" "rectangle/$RECT.plist=from the old Mac"
  run apps rectangle
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "Rectangle: not installed"
  [ ! -e "$PREFS/$RECT.plist" ] || { echo "settings for an app that is not there"; return 1; }
  refute_contains "$(cat "$LOG")" "op "
}

@test "apps: signed out of 1Password, it says what op said and changes nothing" {
  given_stored "Mac app settings" "rectangle/$RECT.plist=from the old Mac"
  OP_REFUSES=signed-out run apps rectangle
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "account is not signed in"
  assert_contains "$output" "Integrate with 1Password CLI"
  [ ! -e "$PREFS/$RECT.plist" ] || { echo "something was imported"; return 1; }
  assert_no_scratch
}

@test "apps: with no document yet, it says how to make one" {
  run apps rectangle
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "no document called \"Mac app settings\""
  assert_contains "$output" "apps-save"
}

@test "apps: an app the document does not hold is named, and the rest go ahead" {
  given_stored "Mac app settings" "rectangle/$RECT.plist=from the old Mac"
  PERSON=1 run apps
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "iStat Menus: nothing is stored for it yet"
  assert_contains "$output" "Rectangle: settings restored"
}

@test "apps: the document is the one DOTFILES_APPS_ITEM names" {
  given_stored "Mac app settings" "rectangle/$RECT.plist=the default one"
  given_stored "Somewhere else" "rectangle/$RECT.plist=the named one"
  DOTFILES_APPS_ITEM="Somewhere else" run apps rectangle
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(cat "$PREFS/$RECT.plist")" "the named one" "Rectangle's settings"
}

@test "apps: two documents of the same name are not chosen between" {
  given_stored "Mac app settings" "rectangle/$RECT.plist=one"
  given_stored "Mac app settings" "rectangle/$RECT.plist=the other"
  run apps rectangle
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "2 documents called"
  [ ! -e "$PREFS/$RECT.plist" ] || { echo "one was chosen: $(cat "$PREFS/$RECT.plist")"; return 1; }
}

@test "apps: settings that could not be written are not called restored" {
  given_stored "Mac app settings" "rectangle/$RECT.plist=from the old Mac"
  DEFAULTS_REFUSES="$RECT" run apps rectangle
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "Rectangle: its settings could not be written"
  refute_contains "$output" "settings restored"
}

@test "apps: an app that exports its own settings is handed its file, with somebody there" {
  given_stored "Mac app settings" "istat-menus/export.ismp7=exported from the old Mac"
  PERSON=1 run apps istat-menus
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(cat "$OPENED/export.ismp7")" "exported from the old Mac" "what the app was handed"
  assert_contains "$(cat "$LOG")" "open -a $APPS/iStat Menus.app "
  assert_contains "$output" "confirm the import"
  refute_contains "$(cat "$LOG")" "defaults import"
  assert_no_scratch
}

@test "apps: with nobody there, such an app is left for later and not opened" {
  given_stored "Mac app settings" "istat-menus/export.ismp7=exported from the old Mac"
  run apps istat-menus
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "iStat Menus: its import takes a person"
  refute_contains "$(cat "$LOG")" "open "
}

# ---------------------------------------------------------------------- by hand

@test "apps: with somebody there, the by-hand step opens the app and its pane" {
  given_stored "Mac app settings" "rectangle/$RECT.plist=from the old Mac"
  PERSON=1 run apps rectangle
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$(cat "$LOG")" "open -a $APPS/Rectangle.app"
  assert_contains "$(cat "$LOG")" "open x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  # The app is opened after its settings are in, so that it reads them.
  assert_equal "$(grep -E "^(defaults import|open -a)" "$LOG" | cut -d' ' -f1-2 | tr '\n' ',')" \
    "defaults import,open -a," "what ran, in order"
}

@test "apps: with nobody there, the by-hand step is said and nothing is opened" {
  given_stored "Mac app settings" "rectangle/$RECT.plist=from the old Mac"
  run apps rectangle
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "by hand: Tick Rectangle"
  refute_contains "$(cat "$LOG")" "open "
}

@test "apps: --walk goes through the by-hand steps and asks 1Password nothing" {
  given_settings "$RECT" "set up here"
  PERSON=1 run apps --walk
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "Rectangle: by hand"
  assert_contains "$output" "iStat Menus: by hand"
  refute_contains "$(cat "$LOG")" "op "
  refute_contains "$(cat "$LOG")" "defaults import"
}

# ------------------------------------------------------------------------- save

@test "apps: --save stores the settings, in a new document and then in the same one" {
  given_settings "$RECT" "set up here"
  run apps --save rectangle
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "Stored in \"Mac app settings\": Rectangle"
  assert_equal "$(stored doc0 "rectangle/$RECT.plist")" "set up here" "what is stored"
  assert_contains "$(cat "$LOG")" "op document create"
  assert_no_scratch

  given_settings "$RECT" "changed since"
  run apps --save rectangle
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(stored doc0 "rectangle/$RECT.plist")" "changed since" "what is stored"
  assert_equal "$(ls "$OP_STORE" | tr '\n' ' ')" "doc0 " "the documents there are"
}

@test "apps: --save keeps what is stored for an app this Mac does not have" {
  given_stored "Mac app settings" \
    "rectangle/$RECT.plist=from another Mac" "istat-menus/export.ismp7=from another Mac too"
  rm -r "$APPS/iStat Menus.app"
  given_settings "$RECT" "set up here"
  run apps --save
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_equal "$(stored doc0 "rectangle/$RECT.plist")" "set up here" "Rectangle, stored"
  assert_equal "$(stored doc0 "istat-menus/export.ismp7")" "from another Mac too" "iStat Menus, stored"
}

@test "apps: --save takes the file an app exported, dragged in with its spaces escaped" {
  given_settings "$ISTAT" "set up here"
  mkdir -p "$AHOME/My Exports"
  echo "exported here" > "$AHOME/My Exports/iStat Menus Settings.ismp7"
  printf '%s \n' "$AHOME/My\\ Exports/iStat\\ Menus\\ Settings.ismp7" > "$INPUT"
  PERSON=1 run apps --save istat-menus
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  assert_contains "$output" "choose Export Settings"
  assert_equal "$(stored doc0 "istat-menus/export.ismp7")" "exported here" "what is stored"
  # The raw domain holds the licence and an identifier for the machine, which
  # is why the app's own export is used for it.
  refute_contains "$(cat "$LOG")" "defaults export"
}

@test "apps: --save refuses a file that is not the app's export, and keeps what is stored" {
  given_stored "Mac app settings" "istat-menus/export.ismp7=stored before"
  given_settings "$ISTAT" "set up here"
  echo "something else" > "$AHOME/notes.txt"
  echo "$AHOME/notes.txt" > "$INPUT"
  PERSON=1 run apps --save istat-menus
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "is not a .ismp7 file"
  assert_equal "$(stored doc0 "istat-menus/export.ismp7")" "stored before" "what is stored"
  refute_contains "$(cat "$LOG")" "op document edit"
}

@test "apps: --save says so when 1Password does not take it" {
  given_settings "$RECT" "set up here"
  OP_REFUSES=write run apps --save rectangle
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  assert_contains "$output" "connection reset"
  refute_contains "$output" "Stored in"
  assert_no_scratch
}

# ------------------------------------------------------------------- the table

@test "apps: a name it does not know is refused, with the ones it does" {
  run apps bartender
  [ "$status" -eq 2 ] || { echo "$output"; return 1; }
  assert_contains "$output" "bartender is not an app this knows"
  assert_contains "$output" "rectangle"
  refute_contains "$(cat "$LOG")" "op "
}

@test "apps: every app in the table is a cask a Brewfile installs" {
  # The name is what the stored folder is called, and what a person types. It
  # being the cask's name is what keeps the two lists from drifting apart. The
  # opt-in Brewfile counts: an app from there is passed over on a Mac that
  # never installed it, like any other that is not there.
  local names name
  names="$(sed -n '/^APPS=(/,/^)/p' "$REPO/script/apps" | sed -n 's/^[[:space:]]*"\([^|]*\)|.*/\1/p')"
  [ -n "$names" ] || { echo "found no rows in the table"; return 1; }
  for name in $names; do
    grep -qhx "cask '$name'" "$REPO/Brewfile" "$REPO/Brewfile.desk" \
      || { echo "$name is not a cask in either Brewfile"; return 1; }
  done
}
