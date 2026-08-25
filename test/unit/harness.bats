#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# The harness itself. A disposable home that reaches back into the real one is
# not disposable: tests would write into the developer's live plugin cache, and
# their results would depend on what happened to be installed there.

@test "harness: a disposable home never links to the real one" {
  local home; home="$(make_home)"
  local target; target="$(readlink "$home/.local/share/zinit" || true)"
  guard_home "$home" && rm -rf "$home"
  [ -n "$target" ] || skip "no plugin cache on this machine to snapshot"
  case "$target" in
    "$REAL_HOME"/*) echo "the fake home links into the real one: $target"; return 1 ;;
  esac
  [ -d "$target" ] || { echo "the snapshot is missing: $target"; return 1; }
}

@test "harness: the snapshot is made once and shared" {
  local a b
  a="$(plugin_cache)" || skip "no plugin cache on this machine"
  b="$(plugin_cache)"
  [ "$a" = "$b" ] || { echo "each call made a new snapshot: $a then $b"; return 1; }
}

@test "harness: guard_home refuses anything outside a temp directory" {
  run guard_home "$REAL_HOME"
  [ "$status" -ne 0 ] || { echo "guard_home accepted the real home"; return 1; }
  run guard_home "/"
  [ "$status" -ne 0 ] || { echo "guard_home accepted /"; return 1; }
}
