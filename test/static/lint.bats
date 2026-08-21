#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

@test "every zsh file parses" {
  local f
  for f in "$REPO"/config/zsh/.zshenv "$REPO"/config/zsh/.zprofile \
           "$REPO"/config/zsh/.zshrc "$REPO"/config/zsh/.zlogin \
           "$REPO"/config/zsh/lib/*.zsh; do
    run "$ZSH_BIN" -n "$f"
    [ "$status" -eq 0 ] || { echo "parse failed: $f"; echo "$output"; return 1; }
  done
}

@test "every autoloaded function parses" {
  local f
  for f in "$REPO"/config/zsh/autoload/*; do
    run "$ZSH_BIN" -n "$f"
    [ "$status" -eq 0 ] || { echo "parse failed: $f"; echo "$output"; return 1; }
  done
}

@test "bash scripts parse and pass shellcheck" {
  local f
  for f in "$REPO"/script/*; do
    [ -f "$f" ] || continue
    case "$f" in *.terminal) continue ;; esac
    run bash -n "$f"
    [ "$status" -eq 0 ] || { echo "parse failed: $f"; echo "$output"; return 1; }
    run shellcheck --severity=warning "$f"
    [ "$status" -eq 0 ] || { echo "shellcheck: $f"; echo "$output"; return 1; }
  done
}

@test "karabiner config is valid json" {
  run jq empty "$REPO/config/karabiner/karabiner.json"
  [ "$status" -eq 0 ]
}

@test "starship config is valid toml" {
  run python3 -c "import tomllib,sys; tomllib.load(open(sys.argv[1],'rb'))" \
    "$REPO/config/starship.toml"
  [ "$status" -eq 0 ]
}

@test "git config parses and keeps signing wired up" {
  run git config --file "$REPO/config/git/config" --list
  [ "$status" -eq 0 ]
  run git config --file "$REPO/config/git/config" --get gpg.ssh.allowedSignersFile
  [ "$status" -eq 0 ]
  run git config --file "$REPO/config/git/config" --get commit.gpgsign
  [ "$output" = "true" ]
}

@test "allowed signers file is well formed" {
  # principal, then options/keytype, then the key material
  run grep -cE '^[^#].* (ssh-ed25519|ssh-rsa|ecdsa-) ' "$REPO/config/git/allowed_signers"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "tmux config loads without error" {
  run tmux -L dotfiles-test -f "$REPO/config/tmux/tmux.conf" \
    new-session -d -s probe
  [ "$status" -eq 0 ] || echo "$output"
  tmux -L dotfiles-test kill-server 2>/dev/null || true
  [ "$status" -eq 0 ]
}

@test "Brewfile is parseable and declares the test tooling" {
  run brew bundle list --file "$REPO/Brewfile"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx bats-core
  echo "$output" | grep -qx shellcheck
}

@test "script/macos only writes defaults to known domains" {
  local known="NSGlobalDomain com.apple.desktopservices com.apple.dock com.apple.finder com.apple.print.PrintingPrefs com.apple.terminal"
  local d
  for d in $(grep -oE '^[[:space:]]*defaults write [A-Za-z0-9.-]+' "$REPO/script/macos" | awk '{print $3}' | sort -u); do
    echo "$known" | grep -qw "$d" || { echo "unknown defaults domain: $d"; return 1; }
  done
}

@test "github workflows are valid yaml and run the whole suite" {
  command -v yq >/dev/null || skip "yq not installed"
  local wf="$REPO/.github/workflows/test.yml"
  run yq -e '.jobs | keys' "$wf"
  [ "$status" -eq 0 ]
  # every tier is actually wired up in CI
  local tier
  for tier in static unit integration; do
    grep -q "bats.*test/$tier" "$wf" || { echo "CI never runs test/$tier"; return 1; }
  done
}

@test "no stray runtime state is lurking under config/" {
  # ~/.config is a symlink into this repo, so tools write their state here.
  # Anything new must be a deliberate decision: track it, or ignore it.
  # Left alone, an allowlisted directory can silently accumulate state that a
  # broad `git add` would then publish.
  local stray
  stray="$(cd "$REPO" && git ls-files --others --exclude-standard -- config/)"
  [ -z "$stray" ] || { echo "untracked and unignored under config/:"; echo "$stray"; return 1; }
}
