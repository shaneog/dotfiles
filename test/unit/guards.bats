#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

setup() {
  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$FAKE_HOME/.local/share" "$FAKE_HOME/.cache"

  # A Homebrew prefix holding stand-ins for the zsh plugins, and for two
  # highlighters nothing here should touch. Each one records that it was
  # sourced, which is all a guard test needs to know.
  PREFIX="$BATS_TEST_TMPDIR/prefix"
  SOURCED="$BATS_TEST_TMPDIR/sourced"
  : > "$SOURCED"
  local plugin
  for plugin in zsh-autosuggestions/zsh-autosuggestions.zsh \
                zsh-history-substring-search/zsh-history-substring-search.zsh \
                zsh-you-should-use/you-should-use.plugin.zsh \
                zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
                zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh; do
    mkdir -p "$PREFIX/share/${plugin%/*}"
    echo "print -r -- ${plugin%/*} >> '$SOURCED'" > "$PREFIX/share/$plugin"
  done
  mkdir -p "$PREFIX/share/zsh-completions"
}

# probe_lib <lib> <code before source> <code after source> [VAR=val ...]
# Sources one lib in a bare shell, so the only thing under test is the lib's
# own guard logic. Homebrew is the stand-in prefix above unless a test says
# otherwise.
probe_lib() {
  local lib="$1" before="$2" after="$3"; shift 3
  env -i HOME="$FAKE_HOME" PATH="${STUBS:+$STUBS:}/usr/bin:/bin" USER=tester \
      XDG_CONFIG_HOME="$REPO/config" XDG_DATA_HOME="$FAKE_HOME/.local/share" \
      XDG_CACHE_HOME="$FAKE_HOME/.cache" HOMEBREW_PREFIX="$PREFIX" "$@" \
      "$ZSH_BIN" -fi -c "
        fpath=($REPO/config/zsh/autoload \$fpath)
        autoload -Uz \$fpath[1]/*(.:t)
        $before
        source '$REPO/config/zsh/lib/$lib'
        $after"
}

# --- node -------------------------------------------------------------------

@test "node: defers entirely when the base layer wraps node" {
  run probe_lib node.zsh 'nvm() { : }' 'print "cache=${NPM_CONFIG_CACHE:-unset}"'
  assert_equal "$output" "cache=unset"
}

@test "node: defers when only node or npm is wrapped" {
  run probe_lib node.zsh 'node() { : }' 'print "${NPM_CONFIG_CACHE:-unset}"'
  assert_equal "$output" "unset"
  run probe_lib node.zsh 'npm() { : }' 'print "${NPM_CONFIG_CACHE:-unset}"'
  assert_equal "$output" "unset"
}

@test "node: keeps npm's cache under XDG when nothing else owns node" {
  run probe_lib node.zsh '' 'print "${NPM_CONFIG_CACHE:-unset}"'
  assert_equal "$output" "$FAKE_HOME/.local/share/npm"
}

# --- common -----------------------------------------------------------------

@test "common: log is the system's command where there is one, not zsh's builtin" {
  [ -x /usr/bin/log ] || skip "NOT CHECKED: this machine has no /usr/bin/log for the builtin to hide"
  run probe_lib common.zsh '' 'whence -w log'
  assert_equal "$output" "log: command"
}

# --- mise -------------------------------------------------------------------

@test "mise: inert when mise is not installed" {
  run probe_lib mise.zsh '' 'print "hooks=$precmd_functions path=$PATH"'
  [[ "$output" != *"mise"* ]]
}

@test "mise: activates when mise is present" {
  STUBS="$(stub_dir)"
  stub_cmd mise <<'STUB'
#!/bin/sh
echo 'MISE_ACTIVATED=yes'
STUB
  run probe_lib mise.zsh '' 'print "activated=${MISE_ACTIVATED:-no}"'
  assert_equal "$output" "activated=yes"
}

@test "mise: the PATH it starts from is this shell's, not the one its cache was written in" {
  # Regression: `mise activate` writes the PATH of the shell that ran it into
  # its output, and the cached copy was sourced as it stood. Every later shell
  # then had the first one's directories appended to its PATH.
  STUBS="$(stub_dir)"
  stub_cmd mise <<'STUB'
#!/bin/sh
echo run >> "$HOME/mise-runs"
printf "export __MISE_ORIG_PATH='%s'\n" "$PATH"
cat <<'SCRIPT'
if [ -z "${__MISE_ORIG_PATH:-}" ]; then
  export __MISE_ORIG_PATH="$PATH"
fi

PATH="$PATH:${__MISE_ORIG_PATH##*:}"
SCRIPT
STUB
  run probe_lib mise.zsh 'path+=(/only/in/the/first/shell)' 'print "last=$path[-1]"'
  assert_equal "$output" "last=/only/in/the/first/shell"

  run probe_lib mise.zsh 'path+=(/second/shell)' 'print "last=$path[-1] start=${__MISE_ORIG_PATH##*:}"'
  assert_equal "$output" "last=/second/shell start=/second/shell"
  # Otherwise the second shell proved nothing about the cache.
  assert_equal "$(wc -l < "$FAKE_HOME/mise-runs" | tr -d ' ')" "1" "times mise was run"
}

@test "mise: does not displace a runtime the base layer wraps" {
  # The migration away from nodenv rests on this: a base layer owning node does
  # so with a shell function, and a function is found before anything mise adds
  # to PATH. If that stopped being true, work's npm -- and the private registry
  # it points at -- would be silently replaced by whatever mise installed.
  STUBS="$(stub_dir)"
  mkdir -p "$STUBS/misebin"
  printf '#!/bin/sh\necho v99.0.0-from-mise\n' > "$STUBS/misebin/node"
  chmod +x "$STUBS/misebin/node"
  stub_cmd mise <<STUB
#!/bin/sh
echo 'export PATH="$STUBS/misebin:\$PATH"'
STUB
  run probe_lib mise.zsh 'node() { print v22.0.0-from-base-layer }' \
    'print "mise_on_path=$([[ $PATH == *misebin* ]] && print yes || print no) node=$(node)"'
  [[ "$output" == *"mise_on_path=yes"* ]] || { echo "mise never got on PATH: $output"; return 1; }
  [[ "$output" == *"node=v22.0.0-from-base-layer"* ]] \
    || { echo "mise displaced the base layer's node: $output"; return 1; }
}

# The Homebrew shellenv is in .zprofile, not in lib/homebrew.zsh: .zshrc's first
# lines need Homebrew's binaries on PATH already. Same shape as probe_lib.
probe_zprofile() {
  local before="$1" after="$2"; shift 2
  # No paths files: what this machine's /etc/paths.d happens to list is not
  # what these tests are about, and on a Mac it lists Homebrew.
  env -i HOME="$FAKE_HOME" PATH="${STUBS:+$STUBS:}/usr/bin:/bin" USER=tester \
      XDG_CONFIG_HOME="$REPO/config" XDG_DATA_HOME="$FAKE_HOME/.local/share" \
      XDG_CACHE_HOME="$FAKE_HOME/.cache" DOTFILES_PATHS_ROOT="$FAKE_HOME/etc" "$@" \
      "$ZSH_BIN" -fi -c "
        $before
        source '$REPO/config/zsh/.zprofile'
        $after"
}

@test "homebrew: does not re-prepend when the base layer set HOMEBREW_PREFIX" {
  [ -d /opt/homebrew ] || skip "no /opt/homebrew on this machine"
  run probe_zprofile '' 'print $PATH' HOMEBREW_PREFIX=/base/brew
  [[ "$output" != *"/opt/homebrew/bin"* ]] \
    || { echo "re-prepended over the base layer's own order: $output"; return 1; }
}

@test "homebrew: sets up shellenv when nothing else did" {
  [ -d /opt/homebrew ] || skip "no /opt/homebrew on this machine"
  run probe_zprofile '' 'print "${HOMEBREW_PREFIX:-unset} $PATH"'
  [[ "$output" == "/opt/homebrew "* ]] || { echo "no prefix: $output"; return 1; }
  [[ "$output" == *"/opt/homebrew/bin"* ]] || { echo "not on PATH: $output"; return 1; }
}

# --- plugins ----------------------------------------------------------------

@test "common: loads no syntax highlighter of its own" {
  # zsh-patina does the highlighting, activated from .zshrc. Two plugins on the
  # same ZLE hook show up as flicker, so nothing here may load one, installed
  # or not.
  probe_lib common.zsh '' ':'
  refute_contains "$(cat "$SOURCED")" "highlighting" "what was sourced"
}

@test "common: skips its autosuggestions when already loaded" {
  probe_lib common.zsh '_zsh_autosuggest_start() { : }' ':'
  refute_contains "$(cat "$SOURCED")" "zsh-autosuggestions" "what was sourced"
}

@test "common: loads autosuggestions when nothing else provides them" {
  probe_lib common.zsh '' ':'
  assert_contains "$(cat "$SOURCED")" "zsh-autosuggestions" "what was sourced"
}

@test "common: the extra completions go behind what is already on fpath" {
  # Homebrew keeps them apart so that they never shadow a completion a tool
  # ships for itself, which holds only if they are searched last.
  run probe_lib common.zsh 'fpath=(/first $fpath)' 'print -r -- $fpath[1] $fpath[-1]'
  assert_equal "$output" "/first $PREFIX/share/zsh-completions"
}

@test "history and alias: each sources its plugin from Homebrew's prefix" {
  probe_lib history.zsh '' ':'
  probe_lib alias.zsh '' ':'
  assert_equal "$(sort "$SOURCED" | tr '\n' ' ')" "zsh-history-substring-search zsh-you-should-use " "what was sourced"
}

@test "a plugin Homebrew has not installed is skipped without a word" {
  # A new machine between its first shell and `brew bundle`, or any machine
  # where one formula was removed: the shell still has to start.
  local lib where
  for where in "HOMEBREW_PREFIX=$BATS_TEST_TMPDIR/empty" "HOMEBREW_PREFIX="; do
    for lib in alias.zsh common.zsh history.zsh; do
      run --separate-stderr probe_lib "$lib" '' 'print ok' "$where"
      assert_equal "$output" "ok" "$lib with $where"
      local noise; noise="$(printf '%s\n' "$stderr" | strip_harness_noise)"
      [ -z "$noise" ] || { echo "$lib with $where wrote: $noise"; return 1; }
    done
  done
  assert_equal "$(cat "$SOURCED")" "" "what was sourced"
}

@test "history: Up and Down are bound only when the search is there to bind them to" {
  run probe_lib history.zsh '' 'bindkey -M emacs "^P"'
  assert_contains "$output" "history-substring-search-up"
  run probe_lib history.zsh '' 'bindkey -M emacs "^P"' "HOMEBREW_PREFIX=$BATS_TEST_TMPDIR/empty"
  assert_contains "$output" "up-line-or-history"
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
  assert_equal "$output" "scalar-export scalar-export scalar-export scalar-export"
}

@test "common: VISUAL follows EDITOR rather than itself" {
  run probe_lib common.zsh '' 'print "$EDITOR/$VISUAL"'
  assert_equal "$output" "nvim/nvim"
}

@test "common: man pages are drawn in colour" {
  run probe_lib common.zsh '' 'print -r -- "${(t)LESS_TERMCAP_md} ${(V)LESS_TERMCAP_md} ${(V)LESS_TERMCAP_us} ${(V)LESS_TERMCAP_me}"'
  assert_equal "$output" "scalar-export ^[[01;31m ^[[01;32m ^[[0m"
}

# --- ls ---------------------------------------------------------------------

@test "alias: the ls macOS ships is asked for colour the way it understands" {
  # BSD ls reads -G as colour. GNU ls reads it as "leave the group out".
  run probe_lib alias.zsh 'OSTYPE=darwin24.0; hash ls=/bin/ls' 'print -r -- "$aliases[ls] / ${(t)LSCOLORS} $LSCOLORS"'
  assert_equal "$output" "ls -G / scalar-export exfxcxdxbxGxDxabagacad"
}

@test "alias: any other ls is asked with --color" {
  run probe_lib alias.zsh 'OSTYPE=darwin24.0; hash ls=/opt/homebrew/opt/coreutils/libexec/gnubin/ls' 'print -r -- "$aliases[ls]"'
  assert_equal "$output" "ls --group-directories-first --color=auto"
  run probe_lib alias.zsh 'OSTYPE=linux-gnu; hash ls=/bin/ls' 'print -r -- "$aliases[ls]"'
  assert_equal "$output" "ls --group-directories-first --color=auto"
}

@test "alias: o opens things where there is an open to do it" {
  run probe_lib alias.zsh 'hash open=/usr/bin/true' 'print -r -- "${aliases[o]:-unset}"'
  assert_equal "$output" "open"
  run probe_lib alias.zsh 'path=(/nowhere)' 'print -r -- "${aliases[o]:-unset}"'
  assert_equal "$output" "unset"
}

# --- line editor ------------------------------------------------------------

@test "editor: a terminal that does not describe a key is not an error" {
  # vt100 has no Home, Insert or Shift-Tab, and binding an empty sequence is
  # an error: one for each, in every shell opened on such a terminal.
  run --separate-stderr probe_lib editor.zsh '' 'bindkey -M emacs "^[b"' TERM=vt100
  local noise; noise="$(printf '%s\n' "$stderr" | strip_harness_noise)"
  [ -z "$noise" ] || { echo "stderr: $noise"; return 1; }
  assert_contains "$output" "emacs-backward-word"
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
  assert_equal "$output" "1"
}

@test "prompt: leaves a dumb terminal alone" {
  stub_starship
  run probe_lib prompt.zsh '' 'print "${STARSHIP_INIT_SOURCED:-no}"' TERM=dumb
  assert_equal "$output" "no"
}

@test "prompt: no-op when starship is not installed" {
  run probe_lib prompt.zsh '' 'print "${STARSHIP_INIT_SOURCED:-no}"' TERM=xterm-256color
  assert_equal "$output" "no"
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
  assert_equal "$output" "/tmp/forwarded-agent"
}

@test "1password: no-op when the agent is not enabled" {
  run probe_lib 1password.zsh '' 'print "${SSH_AUTH_SOCK:-unset}"'
  assert_equal "$output" "unset"
}
