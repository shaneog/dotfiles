#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

setup() {
  ZINIT_LOG="$BATS_TEST_TMPDIR/zinit.log"
  : > "$ZINIT_LOG"
  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$FAKE_HOME/.local/share" "$FAKE_HOME/.cache"
}

# probe_lib <lib> <code before source> <code after source> [VAR=val ...]
# Sources one lib in a bare shell with zinit stubbed out, so the only thing
# under test is the lib's own guard logic.
probe_lib() {
  local lib="$1" before="$2" after="$3"; shift 3
  env -i HOME="$FAKE_HOME" PATH="${STUBS:+$STUBS:}/usr/bin:/bin" USER=tester \
      XDG_CONFIG_HOME="$REPO/config" XDG_DATA_HOME="$FAKE_HOME/.local/share" \
      XDG_CACHE_HOME="$FAKE_HOME/.cache" ZINIT_LOG="$ZINIT_LOG" "$@" \
      zsh -fi -c "
        zinit() { print -r -- \"zinit \$*\" >> \$ZINIT_LOG }
        $before
        source '$REPO/config/zsh/lib/$lib'
        $after"
}

# --- node -------------------------------------------------------------------

@test "node: defers entirely when the base layer wraps node" {
  run probe_lib node.zsh 'nvm() { : }' 'print "root=${NODENV_ROOT:-unset} cache=${NPM_CONFIG_CACHE:-unset}"'
  [ "$output" = "root=unset cache=unset" ]
}

@test "node: defers when only node or npm is wrapped" {
  run probe_lib node.zsh 'node() { : }' 'print "${NODENV_ROOT:-unset}"'
  [ "$output" = "unset" ]
  run probe_lib node.zsh 'npm() { : }' 'print "${NODENV_ROOT:-unset}"'
  [ "$output" = "unset" ]
}

@test "node: configures nodenv when nothing else owns node" {
  run probe_lib node.zsh '' 'print "${NODENV_ROOT:-unset}"'
  [ "$output" = "$FAKE_HOME/.local/share/nodenv" ]
}

# --- sdkman -----------------------------------------------------------------

@test "sdkman: skips init when the base layer already provides sdk" {
  run probe_lib sdkman.zsh 'sdk() { : }' 'print "${SDKMAN_DIR:-unset}"'
  [ "$output" = "unset" ]
}

@test "sdkman: initialises when sdk is absent" {
  run probe_lib sdkman.zsh '' 'print "${SDKMAN_DIR:-unset}"'
  [ "$output" = "$FAKE_HOME/.sdkman" ]
}

# --- homebrew ---------------------------------------------------------------

@test "homebrew: does not re-prepend when the base layer set HOMEBREW_PREFIX" {
  [ -d /opt/homebrew ] || skip "no /opt/homebrew on this machine"
  run probe_lib homebrew.zsh '' 'print $PATH' HOMEBREW_PREFIX=/base/brew
  [[ "$output" != *"/opt/homebrew/bin"* ]]
}

@test "homebrew: sets up shellenv when nothing else did" {
  [ -d /opt/homebrew ] || skip "no /opt/homebrew on this machine"
  run probe_lib homebrew.zsh '' 'print "${HOMEBREW_PREFIX:-unset} $PATH"'
  [[ "$output" == "/opt/homebrew "* ]]
  [[ "$output" == *"/opt/homebrew/bin"* ]]
}

# --- syntax highlighting / autosuggestions ----------------------------------

@test "common: skips its highlighter when one is already loaded" {
  probe_lib common.zsh '_zsh_highlight() { : }' ':'
  ! grep -q "fast-syntax-highlighting" "$ZINIT_LOG"
}

@test "common: skips its autosuggestions when already loaded" {
  probe_lib common.zsh '_zsh_autosuggest_start() { : }' ':'
  ! grep -q "zsh-autosuggestions" "$ZINIT_LOG"
}

@test "common: loads both when nothing else provides them" {
  probe_lib common.zsh '' ':'
  grep -q "fast-syntax-highlighting" "$ZINIT_LOG"
  grep -q "zsh-autosuggestions" "$ZINIT_LOG"
}

# --- prompt -----------------------------------------------------------------

@test "prompt: unhooks a preloaded pure prompt" {
  run probe_lib prompt.zsh \
    'autoload -Uz add-zsh-hook
     prompt_pure_precmd() { : }
     prompt_pure_preexec() { : }
     add-zsh-hook precmd prompt_pure_precmd
     add-zsh-hook preexec prompt_pure_preexec' \
    'print "precmd=$precmd_functions preexec=$preexec_functions"'
  [[ "$output" != *"prompt_pure_precmd"* ]]
  [[ "$output" != *"prompt_pure_preexec"* ]]
}

@test "prompt: always loads starship" {
  probe_lib prompt.zsh '' ':'
  grep -q "starship" "$ZINIT_LOG"
}

# --- python -----------------------------------------------------------------

@test "python: fully inert when pyenv is not installed" {
  run probe_lib python.zsh '' 'print "shell=${PYENV_SHELL:-unset} hook=$precmd_functions path=$PATH"'
  [[ "$output" == "shell=unset hook= path="* ]]
  [[ "$output" != *"pyenv/shims"* ]]
}

@test "python: does not front PATH when pyenv has no shims yet" {
  STUBS="$(stub_cmd pyenv <<'STUB'
#!/bin/sh
exit 0
STUB
)"
  run probe_lib python.zsh '' 'print "shell=${PYENV_SHELL:-unset} path=$PATH"'
  [[ "$output" == "shell=zsh"* ]]
  [[ "$output" != *"pyenv/shims"* ]]
}

@test "python: fronts PATH and hooks precmd once pyenv is usable" {
  STUBS="$(stub_cmd pyenv <<'STUB'
#!/bin/sh
exit 0
STUB
)"
  mkdir -p "$FAKE_HOME/.local/share/pyenv/shims" \
           "$FAKE_HOME/.local/share/pyenv/plugins/pyenv-virtualenv"
  run probe_lib python.zsh '' 'print "path=$PATH hook=$precmd_functions"'
  [[ "$output" == *"pyenv/shims"* ]]
  [[ "$output" == *"_pyenv_virtualenv_hook"* ]]
}

# --- zlogin -----------------------------------------------------------------

@test "zlogin: skips background compilation when told to" {
  cp -R "$REPO/config/zsh" "$BATS_TEST_TMPDIR/zdot"
  find "$BATS_TEST_TMPDIR/zdot" -name '*.zwc*' -delete
  env -i HOME="$FAKE_HOME" PATH="/usr/bin:/bin" ZSH_NO_ZCOMPILE=1 \
    ZDOTDIR="$BATS_TEST_TMPDIR/zdot" zsh -c "source $BATS_TEST_TMPDIR/zdot/.zlogin"
  sleep 1
  [ "$(find "$BATS_TEST_TMPDIR/zdot" -name '*.zwc*' | wc -l | tr -d ' ')" -eq 0 ]
}
