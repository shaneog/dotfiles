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
      "$ZSH_BIN" -fi -c "
        fpath=($REPO/config/zsh/autoload \$fpath)
        autoload -Uz \$fpath[1]/*(.:t)
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

@test "common: no longer loads a syntax highlighter of its own" {
  # zsh-patina does the highlighting now, activated from .zshrc. Two plugins on
  # the same ZLE hook show up as flicker, so nothing here may load one.
  probe_lib common.zsh '' ':'
  ! grep -qiE "syntax-highlighting" "$ZINIT_LOG" \
    || { echo "common.zsh loaded a highlighter: $(cat "$ZINIT_LOG")"; return 1; }
}

@test "common: skips its autosuggestions when already loaded" {
  probe_lib common.zsh '_zsh_autosuggest_start() { : }' ':'
  ! grep -q "zsh-autosuggestions" "$ZINIT_LOG"
}

@test "common: loads autosuggestions when nothing else provides them" {
  probe_lib common.zsh '' ':'
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

# --- python -----------------------------------------------------------------

@test "python: fully inert when pyenv is not installed" {
  run probe_lib python.zsh '' 'print "shell=${PYENV_SHELL:-unset} hook=$precmd_functions path=$PATH"'
  [[ "$output" == "shell=unset hook= path="* ]]
  [[ "$output" != *"pyenv/shims"* ]]
}

@test "python: does not front PATH when pyenv has no shims yet" {
  STUBS="$(stub_dir)"
  stub_cmd pyenv <<'STUB'
#!/bin/sh
exit 0
STUB
  run probe_lib python.zsh '' 'print "shell=${PYENV_SHELL:-unset} path=$PATH"'
  [[ "$output" == "shell=zsh"* ]]
  [[ "$output" != *"pyenv/shims"* ]]
}

@test "python: fronts PATH and hooks precmd once pyenv is usable" {
  STUBS="$(stub_dir)"
  stub_cmd pyenv <<'STUB'
#!/bin/sh
exit 0
STUB
  mkdir -p "$FAKE_HOME/.local/share/pyenv/shims" \
           "$FAKE_HOME/.local/share/pyenv/plugins/pyenv-virtualenv"
  run probe_lib python.zsh '' 'print "path=$PATH hook=$precmd_functions"'
  [[ "$output" == *"pyenv/shims"* ]]
  [[ "$output" == *"_pyenv_virtualenv_hook"* ]]
}

# --- zlogin -----------------------------------------------------------------

# .zlogin forks its work, so give it a moment to land.
run_zlogin() {
  ZDOT="$BATS_TEST_TMPDIR/zdot"
  cp -R "$REPO/config/zsh" "$ZDOT"
  find "$ZDOT" -name '*.zwc*' -delete
  mkdir -p "$FAKE_HOME/.cache/zsh"
  printf '#compdef fake\n' > "$FAKE_HOME/.cache/zsh/zcompdump"
  env -i HOME="$FAKE_HOME" PATH="/usr/bin:/bin" ZDOTDIR="$ZDOT" "$@" \
    "$ZSH_BIN" -c "source $ZDOT/.zlogin"
  local i
  for i in $(seq 1 40); do
    [ -s "$FAKE_HOME/.cache/zsh/zcompdump.zwc" ] && break
    sleep 0.1
  done
}

@test "zlogin: compiles the completion dump" {
  run_zlogin
  [ -s "$FAKE_HOME/.cache/zsh/zcompdump.zwc" ]
}

@test "zlogin: never compiles the zsh sources" {
  # Compiling hand-edited sources races with editing them: a detached compile
  # can write a .zwc that shadows a newer source, so the next shell runs stale
  # code. It also wrote build artefacts into the repo.
  run_zlogin
  local artefacts
  artefacts="$(find "$ZDOT" -name '*.zwc*')"
  [ -z "$artefacts" ] || { echo "compiled sources: $artefacts"; return 1; }
}

@test "zlogin: skips all background work when told to" {
  run_zlogin ZSH_NO_ZCOMPILE=1
  [ ! -e "$FAKE_HOME/.cache/zsh/zcompdump.zwc" ]
  [ -z "$(find "$ZDOT" -name '*.zwc*')" ]
}

# --- environment ------------------------------------------------------------

@test "common: exports the editor and pager environment" {
  run probe_lib common.zsh '' 'print "${(t)EDITOR} ${(t)VISUAL} ${(t)PAGER} ${(t)LESS}"'
  [ "$output" = "scalar-export scalar-export scalar-export scalar-export" ]
}

@test "common: VISUAL follows EDITOR rather than itself" {
  run probe_lib common.zsh '' 'print "$EDITOR/$VISUAL"'
  [ "$output" = "nvim/nvim" ]
}

# --- prompt under a dumb terminal -------------------------------------------

# A stub starship whose init script is observable once sourced.
stub_starship() {
  STUBS="$(stub_dir)"
  stub_cmd starship <<'STUB'
#!/bin/sh
echo 'STARSHIP_INIT_SOURCED=1'
STUB
}

@test "prompt: initialises starship on a capable terminal" {
  stub_starship
  run probe_lib prompt.zsh '' 'print "${STARSHIP_INIT_SOURCED:-no}"' TERM=xterm-256color
  [ "$output" = "1" ]
}

@test "prompt: leaves a dumb terminal alone" {
  stub_starship
  run probe_lib prompt.zsh '' 'print "${STARSHIP_INIT_SOURCED:-no}"' TERM=dumb
  [ "$output" = "no" ]
}

@test "prompt: no-op when starship is not installed" {
  run probe_lib prompt.zsh '' 'print "${STARSHIP_INIT_SOURCED:-no}"' TERM=xterm-256color
  [ "$output" = "no" ]
}

# --- 1password agent --------------------------------------------------------

# The lib tests for a live socket at a fixed path, so create a real one.
# macOS caps unix socket paths at 104 bytes and bats' tmpdir is too deep for
# the Group Containers path, hence the short home.
make_1p_socket() {
  FAKE_HOME="$(mktemp -d /tmp/dotfiles-t.XXXX)"
  local dir="$FAKE_HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t"
  mkdir -p "$dir"
  python3 -c "import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])" "$dir/agent.sock"
}

teardown() {
  case "$FAKE_HOME" in /tmp/dotfiles-t.*) rm -rf "$FAKE_HOME" ;; esac
}

@test "1password: takes over SSH_AUTH_SOCK in a local shell" {
  make_1p_socket
  run probe_lib 1password.zsh '' 'print "$SSH_AUTH_SOCK"'
  [[ "$output" == *"2BUA8C4S2C.com.1password/t/agent.sock" ]]
}

@test "1password: leaves a forwarded agent alone inside an ssh session" {
  make_1p_socket
  run probe_lib 1password.zsh '' 'print "${SSH_AUTH_SOCK:-unset}"' \
    SSH_CONNECTION="10.0.0.1 22 10.0.0.2 22" SSH_AUTH_SOCK=/tmp/forwarded-agent
  [ "$output" = "/tmp/forwarded-agent" ]
}

@test "1password: no-op when the agent is not enabled" {
  run probe_lib 1password.zsh '' 'print "${SSH_AUTH_SOCK:-unset}"'
  [ "$output" = "unset" ]
}
