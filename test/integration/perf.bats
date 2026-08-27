bats_require_minimum_version 1.5.0

load '../helpers/common'

# Startup cost is a feature of this repo (the README tracks it), so guard it.
# Override the ceilings with DOTFILES_STARTUP_BUDGET_MS and
# DOTFILES_NONINTERACTIVE_BUDGET_MS; skip with SKIP_PERF=1.
#
# The defaults sit near what this configuration actually costs -- 137-146ms and
# 17-19ms when measured -- because a ceiling several times the real number only
# catches a catastrophe, and the drift that happens in practice is a plugin
# loaded eagerly instead of on a turbo hook. Runners are slower and set their
# own values.
BUDGET_MS="${DOTFILES_STARTUP_BUDGET_MS:-200}"
NONINTERACTIVE_BUDGET_MS="${DOTFILES_NONINTERACTIVE_BUDGET_MS:-50}"

setup() {
  [ -z "$SKIP_PERF" ] || skip "SKIP_PERF set"
  if ! command -v hyperfine >/dev/null; then
    # Skipping is not passing: on a runner this tier is the only thing measuring
    # startup, and it reported success for months while never once running.
    [ -z "${CI:-}" ] \
      || { echo "hyperfine is missing on a CI runner, so the budget went unchecked"; return 1; }
    skip "hyperfine not installed"
  fi
  FAKE_HOME="$(make_home)"
}

# Must not fail: a skipped test never reaches the FAKE_HOME assignment, and a
# failing teardown is reported as a failing test.
teardown() {
  if [ -n "${FAKE_HOME:-}" ] && guard_home "$FAKE_HOME"; then
    rm -rf "$FAKE_HOME"
  fi
  return 0
}

@test "an interactive login shell starts within budget" {
  local json="$BATS_TEST_TMPDIR/bench.json"
  run hyperfine --warmup 2 --runs 10 --export-json "$json" --shell=none \
    -- "env -i HOME=$FAKE_HOME PATH=$PATH TERM=xterm-256color USER=${USER:-tester} \
        ZSH_NO_TMUX_AUTOSTART=1 ZSH_NO_ZCOMPILE=1 $ZSH_BIN -lic exit"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  local mean_ms
  mean_ms="$(python3 -c "import json,sys; print(round(json.load(open(sys.argv[1]))['results'][0]['mean']*1000))" "$json")"
  echo "mean startup: ${mean_ms}ms (budget ${BUDGET_MS}ms)" >&3
  [ "$mean_ms" -lt "$BUDGET_MS" ] || { echo "over budget"; return 1; }
}

@test "a non-interactive shell is near-free" {
  local json="$BATS_TEST_TMPDIR/bench-ni.json"
  run hyperfine --warmup 2 --runs 10 --export-json "$json" --shell=none \
    -- "env -i HOME=$FAKE_HOME PATH=$PATH $ZSH_BIN -c exit"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  local mean_ms
  mean_ms="$(python3 -c "import json,sys; print(round(json.load(open(sys.argv[1]))['results'][0]['mean']*1000))" "$json")"
  echo "mean non-interactive startup: ${mean_ms}ms (budget ${NONINTERACTIVE_BUDGET_MS}ms)" >&3
  [ "$mean_ms" -lt "$NONINTERACTIVE_BUDGET_MS" ] || { echo "over budget"; return 1; }
}
