#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

setup() {
  HOME_WITH="$(make_home)"    && install_base_layer "$HOME_WITH"
  HOME_WITHOUT="$(make_home)"
}

teardown() {
  local h
  for h in "${HOME_WITH:-}" "${HOME_WITHOUT:-}"; do
    [ -n "$h" ] && guard_home "$h" && rm -rf "$h"
  done
  return 0
}

probe='print "PATH_DUPES=$(print -l $path | sort | uniq -d | tr "\n" ",")"
       print "ZDOTDIR=$ZDOTDIR"
       print "PROFILE_RAN=${BASE_LAYER_PROFILE_RAN:-no} RC_RAN=${BASE_LAYER_RC_RAN:-no}"
       print "PIP=${PIP_CONFIG_FILE:-unset}"
       print "NODE=$(whence -w node 2>/dev/null || print none)"
       print "NPM_CACHE=${NPM_CONFIG_CACHE:-unset}"
       print "MISE=$+functions[_mise_hook]"
       print "STARSHIP=$+functions[prompt_starship_precmd]"
       print "PURE_HOOKED=$precmd_functions[(r)prompt_pure_precmd]"
       print "AUTOSUGGEST=$+functions[_zsh_autosuggest_start]"
       print "BASE_PATH=$path[(r)/base/rc-bin]"'

@test "startup is silent on stderr with a base layer" {
  run --separate-stderr run_login_shell "$HOME_WITH" 'true'
  [ "$status" -eq 0 ]
  local noise; noise="$(printf '%s\n' "$stderr" | strip_harness_noise)"
  [ -z "$noise" ] || { echo "unexpected stderr: $noise"; return 1; }
}

@test "startup is silent on stderr with no base layer" {
  run --separate-stderr run_login_shell "$HOME_WITHOUT" 'true'
  [ "$status" -eq 0 ]
  local noise; noise="$(printf '%s\n' "$stderr" | strip_harness_noise)"
  [ -z "$noise" ] || { echo "unexpected stderr: $noise"; return 1; }
}

@test "a non-interactive shell produces no output at all" {
  run --separate-stderr env -i HOME="$HOME_WITH" PATH="$PATH" "$ZSH_BIN" -c 'true'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "the base layer's own settings survive" {
  run run_login_shell "$HOME_WITH" "$probe"
  echo "$output" | grep -q "PROFILE_RAN=1 RC_RAN=1"
  echo "$output" | grep -q "PIP=/base/pip.conf"
  echo "$output" | grep -qv "BASE_PATH=$"   # /base/rc-bin still on PATH
}

@test "our layer wins where it should" {
  run run_login_shell "$HOME_WITH" "$probe"
  echo "$output" | grep -q "STARSHIP=1"      # starship installed its precmd
  echo "$output" | grep -q "PURE_HOOKED=$"   # pure's hook was removed
  echo "$output" | grep -q "AUTOSUGGEST=1"   # exactly one autosuggester
}

@test "the base layer keeps ownership of node" {
  # Our layer hands node over wholesale rather than half-shadowing it, and mise
  # cannot take it back: nvm's wrapper is a function, so it is found first.
  run run_login_shell "$HOME_WITH" "$probe"
  echo "$output" | grep -q "NODE=node: function"
  echo "$output" | grep -q "NPM_CACHE=unset"
}

@test "our own tooling activates when there is no base layer" {
  run run_login_shell "$HOME_WITHOUT" "$probe"
  command -v mise >/dev/null && { echo "$output" | grep -q "MISE=1" \
    || { echo "mise never activated: $output"; return 1; } }
  echo "$output" | grep -q "PROFILE_RAN=no RC_RAN=no"
  echo "$output" | grep -q "STARSHIP=1"
  echo "$output" | grep -q "NPM_CACHE=$HOME_WITHOUT/.local/share/npm"
}

@test "PATH has no duplicates in either configuration" {
  run run_login_shell "$HOME_WITH" "$probe"
  echo "$output" | grep -q "PATH_DUPES=$"
  run run_login_shell "$HOME_WITHOUT" "$probe"
  echo "$output" | grep -q "PATH_DUPES=$"
}

@test "ZDOTDIR points into the repo" {
  run run_login_shell "$HOME_WITH" "$probe"
  echo "$output" | grep -q "ZDOTDIR=$HOME_WITH/.config/zsh"
}

@test "a non-login interactive shell reads our .zprofile, not the base one" {
  # Regression: the prezto fallback used to run before ZDOTDIR was assigned, so
  # it sourced $HOME/.zprofile (the base layer's) instead of ours.
  run --separate-stderr env -i HOME="$HOME_WITH" PATH="$PATH" \
    USER="${USER:-tester}" TERM=xterm-256color ZSH_NO_TMUX_AUTOSTART=1 "$ZSH_BIN" -ic \
    'print "OURS=${LESSCHARSET:-no} BASE=${BASE_LAYER_PROFILE_RAN:-no}"'
  [ "$output" = "OURS=utf-8 BASE=1" ]
}

@test "completions registered by the base layer survive our compinit" {
  local stubs; stubs="$(stub_dir)"
  stub_cmd aws_completer <<'STUB'
#!/bin/sh
exit 0
STUB
  run env -i HOME="$HOME_WITH" PATH="$stubs:$PATH" USER="${USER:-tester}" \
    TERM="${TERM:-xterm}" ZSH_NO_TMUX_AUTOSTART=1 "$ZSH_BIN" -lic \
    'print "AWS=${_comps[aws]:-MISSING}"'
  echo "$output" | grep -q "AWS=_bash_complete"
}

@test "a real login shell leaves no build artefacts beside the config" {
  # .zlogin runs for real here, with no opt-out, against a copy of the config so
  # that a regression cannot write into the repo working tree.
  local cfg home
  cfg="$(mktemp -d)/config"; mkdir -p "$cfg"
  cp -R "$REPO/config/zsh" "$cfg/zsh"
  cp -R "$REPO/config/tmux" "$cfg/tmux"
  find "$cfg" -name '*.zwc*' -delete
  home="$(mktemp -d)"; guard_home "$home"
  ln -s "$cfg" "$home/.config"
  ln -s "$cfg/zsh/.zshenv" "$home/.zshenv"
  mkdir -p "$home/.cache" "$home/.local/share"
  [ -d "$REAL_HOME/.local/share/zinit" ] \
    && ln -s "$REAL_HOME/.local/share/zinit" "$home/.local/share/zinit"

  _timeout 180 env -i HOME="$home" PATH="$PATH" TERM=xterm-256color \
    USER="${USER:-tester}" ZSH_NO_TMUX_AUTOSTART=1 \
    "$ZSH_BIN" -lic 'true' >/dev/null 2>&1
  sleep 1   # .zlogin forks its work

  local artefacts; artefacts="$(find "$cfg" -name '*.zwc*')"
  local dump_compiled=no
  [ -s "$home/.cache/zsh/zcompdump.zwc" ] && dump_compiled=yes
  rm -rf "$home" "$(dirname "$cfg")"

  [ -z "$artefacts" ] || { echo "startup compiled sources: $artefacts"; return 1; }
  [ "$dump_compiled" = yes ] || { echo "completion dump was not compiled"; return 1; }
}

@test "a login shell caches the completion dump" {
  # The dump's directory is not created by anything else, and the regenerate
  # branch in .zshrc only fires for a dump that already exists -- so without an
  # unconditional mkdir the dump is never written and every shell re-runs
  # compinit. Measured 572ms versus 231ms, so this is the single most expensive
  # thing that can regress here.
  local home; home="$(make_home)"
  _timeout 180 env -i HOME="$home" PATH="$PATH" TERM=xterm-256color \
    USER="${USER:-tester}" ZSH_NO_TMUX_AUTOSTART=1 ZSH_NO_ZCOMPILE=1 \
    "$ZSH_BIN" -lic 'true' >/dev/null 2>&1
  local cached=no
  [ -s "$home/.cache/zsh/zcompdump" ] && cached=yes
  guard_home "$home" && rm -rf "$home"
  [ "$cached" = yes ] || { echo "completion dump was not cached"; return 1; }
}

@test "a local zshrc is sourced, and loads late enough to override" {
  # Documented in the README as the local override for .zshrc. The point of an
  # override is that it wins, so assert ordering rather than mere sourcing:
  # lib/alias.zsh aliases vim to nvim, and the local file must beat it.
  local home; home="$(make_home)"
  printf 'export ZSHRC_LOCAL_RAN=1\nalias vim=local-override\n' > "$home/.zshrc.local"
  run run_login_shell "$home" 'print "ran=${ZSHRC_LOCAL_RAN:-no}"; alias vim'
  guard_home "$home" && rm -rf "$home"
  echo "$output" | grep -q "ran=1" || { echo "the local zshrc was not sourced"; return 1; }
  echo "$output" | grep -q "vim=local-override" \
    || { echo "the local zshrc did not override the config"; return 1; }
}

@test "the deferred alias-tips plugin actually arrives" {
  # Loaded with zinit turbo, so it appears only after the first prompt, which
  # makes silence its failure mode: the feature would simply never show up.
  # Bursting the scheduler is how a non-interactive shell reaches that point.
  local home; home="$(make_home)"
  run run_login_shell "$home" '@zinit-scheduler burst >/dev/null 2>&1
    print "loaded=$+functions[_check_aliases] hooked=$preexec_functions[(r)_check_aliases]"'
  guard_home "$home" && rm -rf "$home"
  echo "$output" | grep -q "loaded=1 hooked=_check_aliases" \
    || { echo "the deferred plugin never loaded: $output"; return 1; }
}

@test "zsh-patina is the only syntax highlighter" {
  command -v zsh-patina >/dev/null || skip "zsh-patina not installed"
  # It shares the line-pre-redraw hook with zsh-syntax-highlighting, which a base
  # layer may have loaded. Two of them fighting is visible as flicker, so assert
  # patina is hooked and any other has been stood down.
  run run_login_shell "$HOME_WITH" 'print "patina=$+functions[_zsh_patina] other=${#ZSH_HIGHLIGHT_HIGHLIGHTERS} fast=$+functions[_fast_highlight]"'
  echo "$output" | grep -q "patina=1 other=0 fast=0" \
    || { echo "highlighting is not solely patina's: $output"; return 1; }
}

@test "everything deferred to after the first prompt actually arrives" {
  # Four things load via zinit turbo to keep them off the critical path. Their
  # failure mode is silence -- no error, the feature simply never appears -- so
  # each one is asserted here. Bursting the scheduler is how a non-interactive
  # shell reaches the point a real one reaches after drawing its prompt.
  local home; home="$(make_home)"
  run run_login_shell "$home" '@zinit-scheduler burst >/dev/null 2>&1
    print "autosuggest=$+functions[_zsh_autosuggest_start]"
    print "utility_aliases=${+aliases[ll]}"
    print "history_binding=$(bindkey -M emacs "^P" | grep -c history-substring-search-up)"'
  guard_home "$home" && rm -rf "$home"
  echo "$output" | grep -q "autosuggest=1"     || { echo "autosuggestions never arrived: $output"; return 1; }
  echo "$output" | grep -q "utility_aliases=1" || { echo "prezto utility never arrived: $output"; return 1; }
  echo "$output" | grep -q "history_binding=1" || { echo "history bindings never arrived: $output"; return 1; }
}

@test "docker completion is generated from the installed CLI" {
  command -v docker >/dev/null || skip "docker not installed"
  # Replaces a plugin that cost 20ms per shell and vendored upstream's copy.
  local home; home="$(make_home)"
  run run_login_shell "$home" 'print "file=$(wc -c < ${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions/_docker) onfpath=$(print -l $fpath | grep -c zsh/completions)"'
  guard_home "$home" && rm -rf "$home"
  echo "$output" | grep -q "onfpath=1" || { echo "not on fpath: $output"; return 1; }
  echo "$output" | grep -qE "file=[0-9]{3,}" || { echo "completion not generated: $output"; return 1; }
}

@test "completion styling is ours, and nothing of ours runs a second compinit" {
  # Prezto's completion module supplied these styles, and alongside them its own
  # compinit against its own dump -- part of four compinits and three dumps per
  # shell. The styles moved into lib/completion.zsh and the module was dropped.
  # Both halves are asserted because either failing is silent: completion just
  # quietly behaves differently, and a stray dump is invisible until it is stale.
  local home; home="$(make_home)"
  run _timeout 180 env -i HOME="$home" PATH="$PATH" TERM=xterm-256color \
    USER="${USER:-tester}" ZSH_NO_TMUX_AUTOSTART=1 ZSH_NO_ZCOMPILE=1 \
    "$ZSH_BIN" -lic '
      print "menu=$(zstyle -L ":completion:*:*:*:*:*" | grep -c "menu select")"
      print "nocase=$(zstyle -L ":completion:*" matcher-list | grep -c lower)"
      print "cache=$(zstyle -L ":completion::complete:*" cache-path | grep -c "zsh/zcompcache")"'
  local strays; strays="$(find "$home/.cache" -name zcompdump -not -path "*/zsh/*" 2>/dev/null | wc -l | tr -d ' ')"
  guard_home "$home" && rm -rf "$home"
  echo "$output" | grep -q "menu=1"   || { echo "menu selection style is missing: $output"; return 1; }
  echo "$output" | grep -q "nocase=1" || { echo "case-insensitive matching is missing: $output"; return 1; }
  echo "$output" | grep -q "cache=1"  || { echo "completion cache path is not ours: $output"; return 1; }
  [ "$strays" = 0 ] || { echo "something wrote a second completion dump"; return 1; }
}

@test "fzf's file command actually returns files" {
  # This shipped broken: FZF_DEFAULT_COMMAND called rg, rg was in no Brewfile,
  # and fzf treats a failing command as an empty result set -- so Ctrl-T quietly
  # listed nothing on every machine. Asserting the widget exists was not enough,
  # because the widget existed the whole time. Assert output instead.
  command -v rg >/dev/null || skip "ripgrep not installed"
  local home; home="$(make_home)"
  run _timeout 180 env -i HOME="$home" PATH="$PATH" TERM=xterm-256color \
    USER="${USER:-tester}" ZSH_NO_TMUX_AUTOSTART=1 ZSH_NO_ZCOMPILE=1 \
    "$ZSH_BIN" -lic "cd $REPO && eval \"\$FZF_DEFAULT_COMMAND\" | wc -l"
  guard_home "$home" && rm -rf "$home"
  local lines; lines="$(echo "$output" | tr -d ' ' | grep -E '^[0-9]+$' | tail -1)"
  [ -n "$lines" ] && [ "$lines" -gt 0 ] \
    || { echo "fzf's file command produced no files: $output"; return 1; }
}
