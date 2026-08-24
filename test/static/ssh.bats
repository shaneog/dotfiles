bats_require_minimum_version 1.5.0

load '../helpers/common'

setup() {
  SSH_HOME="$(mktemp -d)"
  guard_home "$SSH_HOME"
  mkdir -p "$SSH_HOME/.ssh"
  : > "$SSH_HOME/.ssh/config-local"
}

teardown() {
  if [ -n "${SSH_HOME:-}" ] && guard_home "$SSH_HOME"; then
    rm -rf "$SSH_HOME"
  fi
  return 0
}

# Effective config for a host, as ssh itself resolves it (no network involved).
effective() {
  HOME="$SSH_HOME" ssh -G -F "$REPO/ssh/config" "$1" 2>/dev/null
}

@test "config parses and resolves" {
  run effective example.com
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "^host example.com"
}

@test "the intended keepalive settings are the effective ones" {
  run effective example.com
  echo "$output" | grep -qx "serveraliveinterval 30"
  echo "$output" | grep -qx "serveralivecountmax 10"
  echo "$output" | grep -qx "tcpkeepalive no"
}

@test "no keyword is set twice" {
  local dupes
  dupes="$(grep -vE '^\s*(#|$|Host |Include )' "$REPO/ssh/config" \
    | awk '{print tolower($1)}' | sort | uniq -d)"
  [ -z "$dupes" ] || { echo "duplicated keywords: $dupes"; return 1; }
}

@test "config-local can override, not merely append" {
  # The regression: with Include last, this override was ignored.
  # accept-new is used because ssh normalises "no" to "false" in -G output.
  echo "StrictHostKeyChecking accept-new" > "$SSH_HOME/.ssh/config-local"
  run effective example.com
  echo "$output" | grep -qx "stricthostkeychecking accept-new"
}

@test "the shipped default still applies with an empty config-local" {
  run effective example.com
  echo "$output" | grep -qx "stricthostkeychecking ask"
}

@test "config-local can override a Host * setting too" {
  echo "Compression no" > "$SSH_HOME/.ssh/config-local"
  run effective example.com
  echo "$output" | grep -qx "compression no"
}

@test "authentication goes through 1Password's agent, not keys on disk" {
  run effective example.com
  echo "$output" | grep -qi "^identityagent .*1password.*agent.sock" \
    || { echo "no 1Password agent configured: $(echo "$output" | grep -i identityagent)"; return 1; }
  # Setting IdentitiesOnly would restrict auth to IdentityFile entries, of which
  # there are none, so it must stay off for agent keys to be offered.
  echo "$output" | grep -qx "identitiesonly no"
}

@test "config-local can still redirect the agent" {
  echo 'IdentityAgent /tmp/some-other-agent.sock' > "$SSH_HOME/.ssh/config-local"
  run effective example.com
  echo "$output" | grep -qx "identityagent /tmp/some-other-agent.sock"
}
