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
# SSH_CONNECTION is cleared because the config now branches on it, and these
# tests would otherwise report different answers when run over ssh.
effective() {
  env -u SSH_CONNECTION HOME="$SSH_HOME" ssh -G -F "$REPO/ssh/config" "$1" 2>/dev/null
}

# The same, as it resolves inside an inbound ssh session.
effective_in_ssh() {
  SSH_CONNECTION="1.2.3.4 22 5.6.7.8 22" HOME="$SSH_HOME" \
    ssh -G -F "$REPO/ssh/config" "$1" 2>/dev/null
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

@test "no keyword is set twice within one block" {
  # Per block, not per file: IdentityAgent is deliberately set once for inbound
  # ssh sessions and once for everything else, and ssh keeps the first match.
  local dupes
  dupes="$(awk '
    /^[[:space:]]*(#|$)/            { next }
    /^[[:space:]]*Include[[:space:]]/ { next }
    /^[[:space:]]*(Host|Match)[[:space:]]/ { block = $0; next }
    { k = tolower($1); if (seen[block "\t" k]++) print (block == "" ? "top level" : block) " -> " k }
  ' "$REPO/ssh/config")"
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

@test "an inbound ssh session defers to the forwarded agent" {
  # IdentityAgent overrides SSH_AUTH_SOCK, so a Host * path would send onward
  # hops to 1Password's socket and block on an approval nobody can give. The
  # literal string means "read the environment", which is what lib/1password.zsh
  # deliberately leaves alone in the same situation.
  run effective_in_ssh example.com
  echo "$output" | grep -qx "identityagent SSH_AUTH_SOCK" \
    || { echo "an inbound session would not use the forwarded agent: $(echo "$output" | grep -i identityagent)"; return 1; }
}

@test "a local session still uses 1Password's agent directly" {
  run effective example.com
  echo "$output" | grep -qi "^identityagent .*1password.*agent.sock" \
    || { echo "local sessions lost the 1Password agent: $(echo "$output" | grep -i identityagent)"; return 1; }
}

@test "config-local can still redirect the agent" {
  echo 'IdentityAgent /tmp/some-other-agent.sock' > "$SSH_HOME/.ssh/config-local"
  run effective example.com
  echo "$output" | grep -qx "identityagent /tmp/some-other-agent.sock"
}
