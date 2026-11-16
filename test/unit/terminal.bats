#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# lib/terminal.zsh, asked what it would send a terminal. The hooks are run by
# hand and their output spelled out, so an escape sequence reads as ^[ and the
# bell that ends a title as ^G.

setup() {
  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$FAKE_HOME/a-very-long-directory-name/in side"
}

# titles <zsh that runs hooks> [VAR=val ...]
titles() {
  local code="$1"; shift
  env -i HOME="$FAKE_HOME" PATH="/usr/bin:/bin" USER=tester HOST=here TERM=xterm-256color "$@" \
    "$ZSH_BIN" -fi -c "
      source '$REPO/config/zsh/lib/terminal.zsh'
      before_prompt() { local hook; for hook in \$precmd_functions; do \$hook; done }
      before_command() { local hook; for hook in \$preexec_functions; do \$hook \"\$1\" \"\$1\" \"\$1\"; done }
      cd ~/'a-very-long-directory-name/in side'
      print -r -- \"\${(V)\$($code)}\"" 2>/dev/null
}

@test "terminal: the title is the folder while the prompt waits, shortened for a tab" {
  run titles before_prompt
  assert_equal "$output" "^[]1;...name/in side^G^[]2;~/a-very-long-directory-name/in side^G"
}

@test "terminal: the title is the command while one runs, not what is in front of it" {
  run titles 'before_command "LANG=C sudo -n /usr/local/bin/a-rather-long-command --flag argument"'
  assert_equal "$output" "^[]1;a-rather-lon...^G^[]2;a-rather-long-command^G"
}

@test "terminal: inside tmux the titles are left to tmux" {
  run titles 'before_prompt; before_command ls' TMUX=/tmp/tmux-0/default,1,0
  assert_equal "$output" ""
}

@test "terminal: a terminal that cannot show a title is sent nothing" {
  run titles 'before_prompt; before_command ls' TERM=dumb
  assert_equal "$output" ""
}

@test "terminal: Terminal.app is told the folder, and nothing about titles" {
  run titles before_prompt TERM_PROGRAM=Apple_Terminal
  assert_equal "$output" "^[]7;file://here$FAKE_HOME/a-very-long-directory-name/in%20side^G"
}

@test "terminal: Terminal.app forgets the folder when the command leaves this shell" {
  run titles 'before_command "ssh somewhere"; print -n -- " and "; before_command "ls -l"' TERM_PROGRAM=Apple_Terminal
  assert_equal "$output" "^[]7;^G and "
}
