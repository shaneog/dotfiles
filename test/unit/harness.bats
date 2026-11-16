#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# The harness itself.

@test "harness: guard_home refuses anything outside a temp directory" {
  run guard_home "$REAL_HOME"
  [ "$status" -ne 0 ] || { echo "guard_home accepted the real home"; return 1; }
  run guard_home "/"
  [ "$status" -ne 0 ] || { echo "guard_home accepted /"; return 1; }
}
