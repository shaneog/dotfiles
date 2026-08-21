bats_require_minimum_version 1.5.0

load '../helpers/common'

setup() {
  LOG="$BATS_TEST_TMPDIR/cmds.log"; : > "$LOG"
  STUBS="$BATS_TEST_TMPDIR/stubs"; mkdir -p "$STUBS"
  # sudo has to exec its arguments, otherwise the commands it wraps never run
  # and their exit status can never be observed.
  printf '#!/bin/sh\nexec "$@"\n' > "$STUBS/sudo"
  for c in networksetup ifconfig; do
    cat > "$STUBS/$c" <<STUB
#!/bin/sh
echo "$c \$*" >> "\$LOG"
exit 0
STUB
    chmod +x "$STUBS/$c"
  done
  chmod +x "$STUBS/sudo"
}

randommac() {
  env -i HOME="$BATS_TEST_TMPDIR" PATH="$STUBS:/usr/bin:/bin:/opt/homebrew/bin" \
      LOG="$LOG" "$@" \
      zsh -fic "fpath=($REPO/config/zsh/autoload \$fpath)
                autoload -Uz randommac
                randommac \${RANDOMMAC_IFACE:-}"
}

@test "powers the interface down, sets the address, powers it back up" {
  run randommac
  [ "$status" -eq 0 ]
  grep -q "networksetup -setairportpower en0 off" "$LOG"
  grep -q "ifconfig en0 ether" "$LOG"
  grep -q "networksetup -setairportpower en0 on" "$LOG"
  # ordering: down before set, set before up
  [ "$(grep -n 'setairportpower en0 off' "$LOG" | cut -d: -f1)" -lt \
    "$(grep -n 'ifconfig en0 ether' "$LOG" | cut -d: -f1)" ]
}

@test "generates a well-formed, locally administered unicast address" {
  run randommac
  local mac
  mac="$(grep -o 'ether [0-9a-f:]*' "$LOG" | awk '{print $2}')"
  echo "generated: $mac"
  [[ "$mac" =~ ^[0-9a-f]{2}(:[0-9a-f]{2}){5}$ ]]
  local first=$((16#${mac%%:*}))
  [ $(( first & 1 )) -eq 0 ]   # unicast
  [ $(( first & 2 )) -eq 2 ]   # locally administered
}

@test "produces a different address each time" {
  randommac; randommac; randommac
  local uniq
  uniq="$(grep -o 'ether [0-9a-f:]*' "$LOG" | sort -u | wc -l | tr -d ' ')"
  [ "$uniq" -ge 2 ]
}

@test "accepts an explicit interface" {
  run randommac RANDOMMAC_IFACE=en1
  grep -q "ifconfig en1 ether" "$LOG"
}

@test "restores power if setting the address fails" {
  cat > "$STUBS/ifconfig" <<'STUB'
#!/bin/sh
echo "ifconfig $*" >> "$LOG"
exit 1
STUB
  chmod +x "$STUBS/ifconfig"
  run randommac
  [ "$status" -ne 0 ]
  [ "$(grep -c 'setairportpower en0 on' "$LOG")" -ge 1 ]
}
