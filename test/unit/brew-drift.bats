#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# script/brew-drift compares this machine against the Brewfile in both
# directions. Its two ways of being wrong are both false positives, which is how
# a check gets ignored: reporting a dependency as an unwanted extra, and
# reporting a declared formula as absent when it is installed as some other
# formula's dependency.

setup() {
  FIX="$BATS_TEST_TMPDIR/repo"
  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$FIX/script" "$STUBS"
  cp "$REPO/script/brew-drift" "$FIX/script/brew-drift"
  printf "brew 'fzf'\ncask '1password'\n" > "$FIX/Brewfile"
}

# $1: newline-separated "name<TAB>on_request" formulae
# $2: newline-separated installed formula names (including dependencies)
# $3: newline-separated installed cask tokens
stub_brew() {
  local requested="$1" installed="$2" casks="$3"
  {
    echo '#!/bin/sh'
    echo 'case "$1 $2 $3" in'
    printf '  "info --json=v2 --installed") cat <<'"'"'JSON'"'"'\n'
    printf '{"formulae":['
    local first=1 name flag
    while IFS="$(printf '\t')" read -r name flag; do
      [ -n "$name" ] || continue
      [ "$first" -eq 1 ] || printf ','
      printf '{"name":"%s","desc":"a tool","installed":[{"installed_on_request":%s}]}' "$name" "$flag"
      first=0
    done <<EOF
$requested
EOF
    printf '],"casks":[]}\n'
    echo 'JSON'
    echo '    ;;'
    echo 'esac'
    echo 'case "$1 $2" in'
    printf '  "list --formula") printf "%%s\\\\n" %s ;;\n' "$(printf '%s' "$installed" | tr '\n' ' ')"
    printf '  "list --cask") printf "%%s\\\\n" %s ;;\n' "$(printf '%s' "$casks" | tr '\n' ' ')"
    echo 'esac'
    echo 'exit 0'
  } > "$STUBS/brew"
  chmod +x "$STUBS/brew"
}

drift() {
  ( cd "$FIX" && PATH="$STUBS:$PATH" ./script/brew-drift )
}

@test "brew-drift: a machine that matches the Brewfile reports nothing" {
  stub_brew "$(printf 'fzf\ttrue')" "fzf" "1password"
  run drift
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  echo "$output" | grep -q "0 undeclared, 0 declared but absent" || { echo "$output"; return 1; }
}

@test "brew-drift: something installed on request and not declared is reported" {
  stub_brew "$(printf 'fzf\ttrue\nentr\ttrue')" "$(printf 'fzf\nentr')" "1password"
  run drift
  echo "$output" | grep -q "entr" || { echo "entr was not reported: $output"; return 1; }
  echo "$output" | grep -q "1 undeclared" || { echo "$output"; return 1; }
}

@test "brew-drift: a dependency is not reported as an unwanted extra" {
  # gettext arrives because something else needs it. Reporting it would bury the
  # handful of entries that are actually decisions.
  stub_brew "$(printf 'fzf\ttrue\ngettext\tfalse')" "$(printf 'fzf\ngettext')" "1password"
  run drift
  echo "$output" | grep -q "gettext" && { echo "a dependency was reported: $output"; return 1; }
  echo "$output" | grep -q "0 undeclared" || { echo "$output"; return 1; }
}

@test "brew-drift: a declared formula installed as a dependency is not called absent" {
  # The bug this pins: absence was checked against the requested list, so a
  # declared formula that arrived as a dependency was reported missing.
  printf "brew 'gettext'\n" >> "$FIX/Brewfile"
  stub_brew "$(printf 'fzf\ttrue')" "$(printf 'fzf\ngettext')" "1password"
  run drift
  echo "$output" | grep -q "0 declared but absent" \
    || { echo "an installed dependency was called absent: $output"; return 1; }
}

@test "brew-drift: a tap-qualified name matches a plain declaration" {
  printf "brew 'tart'\n" >> "$FIX/Brewfile"
  stub_brew "$(printf 'fzf\ttrue\nopenai/tools/tart\ttrue')" "$(printf 'fzf\nopenai/tools/tart')" "1password"
  run drift
  echo "$output" | grep -q "0 undeclared, 0 declared but absent" \
    || { echo "tap-qualified name did not match: $output"; return 1; }
}

@test "brew-drift: a declared cask that is not installed is reported" {
  stub_brew "$(printf 'fzf\ttrue')" "fzf" ""
  run drift
  echo "$output" | grep -q "1password" || { echo "$output"; return 1; }
  echo "$output" | grep -q "1 declared but absent" || { echo "$output"; return 1; }
}

@test "brew-drift: an undeclared cask is reported" {
  stub_brew "$(printf 'fzf\ttrue')" "fzf" "$(printf '1password\norbstack')"
  run drift
  echo "$output" | grep -q "orbstack" || { echo "$output"; return 1; }
}

@test "brew-drift: without brew it says so rather than reporting nothing" {
  run env -i HOME="$HOME" PATH="/usr/bin:/bin" bash -c "cd '$FIX' && ./script/brew-drift"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "not installed" \
    || { echo "a check that cannot run must say so: $output"; return 1; }
}
