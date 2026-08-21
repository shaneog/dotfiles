bats_require_minimum_version 1.5.0

load '../helpers/common'

# Startup cost is a feature of this repo (the README tracks it), so guard it.
# Override the ceiling with DOTFILES_STARTUP_BUDGET_MS; skip with SKIP_PERF=1.
BUDGET_MS="${DOTFILES_STARTUP_BUDGET_MS:-1500}"

setup() {
  [ -z "$SKIP_PERF" ] || skip "SKIP_PERF set"
  command -v hyperfine >/dev/null || skip "hyperfine not installed"
  FAKE_HOME="$(make_home)"
}

teardown() {
  [ -n "${FAKE_HOME:-}" ] && guard_home "$FAKE_HOME" && rm -rf "$FAKE_HOME"
}

@test "an interactive login shell starts within budget" {
  local json="$BATS_TEST_TMPDIR/bench.json"
  run hyperfine --warmup 2 --runs 10 --export-json "$json" --shell=none \
    -- "env -i HOME=$FAKE_HOME PATH=$PATH TERM=xterm-256color USER=${USER:-tester} \
        ZSH_NO_TMUX_AUTOSTART=1 ZSH_NO_ZCOMPILE=1 zsh -lic exit"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  local mean_ms
  mean_ms="$(python3 -c "import json,sys; print(round(json.load(open(sys.argv[1]))['results'][0]['mean']*1000))" "$json")"
  echo "mean startup: ${mean_ms}ms (budget ${BUDGET_MS}ms)"
  [ "$mean_ms" -lt "$BUDGET_MS" ] || { echo "over budget"; return 1; }
}

@test "a non-interactive shell is near-free" {
  local json="$BATS_TEST_TMPDIR/bench-ni.json"
  run hyperfine --warmup 2 --runs 10 --export-json "$json" --shell=none \
    -- "env -i HOME=$FAKE_HOME PATH=$PATH zsh -c exit"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  local mean_ms
  mean_ms="$(python3 -c "import json,sys; print(round(json.load(open(sys.argv[1]))['results'][0]['mean']*1000))" "$json")"
  echo "mean non-interactive startup: ${mean_ms}ms"
  [ "$mean_ms" -lt 150 ]
}
