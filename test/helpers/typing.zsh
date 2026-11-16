# For a test that types into a shell on a terminal of its own and waits for it
# to write a file. Sourced by the zsh doing the typing, after it has started the
# shell with `zpty -b shell ...`.

# Everything the shell has shown so far. Left unread, its output fills the
# terminal and stops it, so the wait below reads as it goes.
seen=
typeset -F SECONDS

wait_for() {  # a file the shell writes, tenths of a second to allow
  local more
  local -i allow=$2
  # script/mutate breaks what the test is waiting for, so a run of its own is
  # expected to end here, and it says how long that is worth waiting for.
  (( ${DOTFILES_TEST_PATIENCE:-allow} < allow )) && allow=$DOTFILES_TEST_PATIENCE
  # By the clock: a pass that reads nothing takes longer than the sleep in it,
  # and on a busy machine a count of passes allowed twice what it said.
  local -F deadline=$(( SECONDS + allow / 10. ))
  until [[ -e $1 ]]; do
    zpty -r shell more 2>/dev/null && seen+=$more
    (( SECONDS > deadline )) && return 1
    sleep 0.1
  done
}
