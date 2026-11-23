#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

setup() {
  FAKE_HOME="$(mktemp -d)"
  guard_home "$FAKE_HOME"
}

teardown() {
  if [ -n "${FAKE_HOME:-}" ] && guard_home "$FAKE_HOME"; then
    rm -rf "$FAKE_HOME"
  fi
  return 0
}

run_setup() {
  ( cd "${CLONE:-$REPO}" && HOME="$FAKE_HOME" ./script/setup ) >/dev/null 2>&1
}

# A small clone of its own for a test to run setup from, where the test needs
# files in the clone that git does not track. script/setup works on whichever
# clone it is run from, and it moves such files, so the real one is not a
# test's to seed. The script is copied as it is on disk now.
make_clone() {
  CLONE="$FAKE_HOME/.dotfiles"
  mkdir -p "$CLONE/script" "$CLONE/config/zsh" "$CLONE/config/nvim" "$CLONE/ssh"
  mkdir -p "$CLONE/claude/skills/tidy" "$CLONE/claude/agents"
  cp "$REPO/script/setup" "$CLONE/script/setup"
  echo "# ours" > "$CLONE/config/zsh/.zshenv"
  echo "-- ours" > "$CLONE/config/nvim/init.lua"
  echo "# ours" > "$CLONE/config/starship.toml"
  echo "# ours" > "$CLONE/ssh/config"
  echo "# ours" > "$CLONE/Brewfile"
  echo "# ours" > "$CLONE/claude/CLAUDE.md"
  echo '{"ours": true}' > "$CLONE/claude/settings.json"
  echo "# ours" > "$CLONE/claude/skills/tidy/SKILL.md"
  echo "# ours" > "$CLONE/claude/agents/reviewer.md"
  git -C "$CLONE" init -q
  git -C "$CLONE" add -A
}

# The home an earlier script/setup left behind: ~/.config and ~/.ssh as links
# to the clone's whole directories, and so other tools' files inside the clone.
make_whole_directory_home() {
  make_clone
  ln -s "$CLONE/config" "$FAKE_HOME/.config"
  ln -s "$CLONE/ssh" "$FAKE_HOME/.ssh"
  ln -s "$FAKE_HOME/.config/zsh/.zshenv" "$FAKE_HOME/.zshenv"
  mkdir -p "$FAKE_HOME/.config/some-other-tool"
  echo "keep me" > "$FAKE_HOME/.config/some-other-tool/state"
  echo "hidden" > "$FAKE_HOME/.config/.hidden-state"
  echo "example.com ssh-ed25519 AAAA" > "$FAKE_HOME/.ssh/known_hosts"
  echo "Host local" > "$FAKE_HOME/.ssh/config-local"
}

mode_of() { ls -ld "$1" | cut -c1-10; }

# Normalised snapshot of the home directory, and of the directories setup
# links into: name plus symlink target.
snapshot() {
  local f
  for f in "$FAKE_HOME"/.* "$FAKE_HOME"/* "$FAKE_HOME"/.config/* "$FAKE_HOME"/.ssh/* \
           "$FAKE_HOME"/.claude/* "$FAKE_HOME"/.claude/*/*; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    case "${f##*/}" in .|..) continue ;; esac
    if [ -L "$f" ]; then echo "${f#"$FAKE_HOME"/} -> $(readlink "$f")"
    elif [ -d "$f" ]; then echo "${f#"$FAKE_HOME"/} (dir)"
    else echo "${f#"$FAKE_HOME"/} (file)"; fi
  done | sort
}

@test "never creates the four externally managed shell files" {
  run_setup
  local f
  for f in .profile .bashrc .zprofile .zshrc; do
    [ ! -e "$FAKE_HOME/$f" ] || { echo "setup created $f"; return 1; }
  done
}

@test "leaves pre-existing managed shell files untouched" {
  local f
  for f in .profile .bashrc .zprofile .zshrc; do
    echo "MANAGED CONTENT $f" > "$FAKE_HOME/$f"
  done
  run_setup
  for f in .profile .bashrc .zprofile .zshrc; do
    [ "$(cat "$FAKE_HOME/$f")" = "MANAGED CONTENT $f" ] \
      || { echo "setup modified $f"; return 1; }
  done
}

@test "links .zshenv into the repo" {
  run_setup
  [ -L "$FAKE_HOME/.zshenv" ]
  [ "$FAKE_HOME/.zshenv" -ef "$REPO/config/zsh/.zshenv" ]
}

@test "backs up a real .zshenv instead of clobbering it" {
  echo "PRE-EXISTING" > "$FAKE_HOME/.zshenv"
  run_setup
  [ -L "$FAKE_HOME/.zshenv" ]
  run cat "$FAKE_HOME"/.zshenv.bak.*
  assert_equal "$output" "PRE-EXISTING"
}

@test "is idempotent" {
  run_setup
  local first; first="$(snapshot)"
  run_setup
  local second; second="$(snapshot)"
  [ "$first" = "$second" ] || { diff <(echo "$first") <(echo "$second"); return 1; }
}

@test "links each entry git tracks under config, inside a real ~/.config" {
  run_setup
  [ -d "$FAKE_HOME/.config" ]
  [ ! -L "$FAKE_HOME/.config" ] || { echo "~/.config is a link"; return 1; }
  local entry
  for entry in gh ghostty git homebrew karabiner mise nvim starship.toml tmux zsh; do
    [ -L "$FAKE_HOME/.config/$entry" ] || { echo "$entry is not linked"; return 1; }
    [ "$FAKE_HOME/.config/$entry" -ef "$REPO/config/$entry" ] \
      || { echo "$entry points somewhere else"; return 1; }
  done
  [ "$FAKE_HOME/.Brewfile" -ef "$REPO/Brewfile" ]
}

@test "what another tool writes under ~/.config stays out of the clone" {
  # Regression: ~/.config was a link to the clone's config directory, so every
  # tool's state landed in a public repo's working tree, and went with the
  # clone when the clone was deleted.
  make_clone
  run_setup
  mkdir -p "$FAKE_HOME/.config/some-other-tool"
  echo "state" > "$FAKE_HOME/.config/some-other-tool/state"
  assert_equal "$(ls -A "$CLONE/config" | tr '\n' ' ')" "nvim starship.toml zsh " \
    "the clone's config directory"
}

@test "links the four things it names, and nothing else at the top of the clone" {
  # Regression: setup linked every top-level entry that a skip pattern did not
  # name, so a file added to the repo turned up in home as ~/.<name> until
  # somebody remembered the pattern.
  make_clone
  mkdir -p "$CLONE/test" "$CLONE/some-new-directory"
  echo "# ours" > "$CLONE/test/a.bats"
  echo "# ours" > "$CLONE/some-new-directory/file"
  echo "# ours" > "$CLONE/Makefile"
  echo "# ours" > "$CLONE/some-new-file"
  git -C "$CLONE" add -A
  run_setup
  # .dotfiles is the clone itself, which make_clone keeps in the home.
  assert_equal "$(ls -A "$FAKE_HOME" | LC_ALL=C sort | tr '\n' ' ')" \
    ".Brewfile .claude .config .dotfiles .ssh .zshenv " "what setup left in the home"
}

@test "does not link what git does not track" {
  # A directory somebody is still working on, or one a tool left behind.
  make_clone
  mkdir -p "$CLONE/config/not-added-yet"
  run_setup
  [ ! -e "$FAKE_HOME/.config/not-added-yet" ] \
    || { echo "an untracked directory was linked"; return 1; }
  [ -d "$CLONE/config/not-added-yet" ] || { echo "it was moved out of the clone"; return 1; }
}

@test "leaves other tools' files under ~/.config where they are" {
  # Any machine that has been used already has files under ~/.config.
  mkdir -p "$FAKE_HOME/.config/some-other-tool"
  echo "keep me" > "$FAKE_HOME/.config/some-other-tool/state"
  run_setup
  assert_equal "$(cat "$FAKE_HOME/.config/some-other-tool/state")" "keep me"
  [ "$FAKE_HOME/.config/zsh" -ef "$REPO/config/zsh" ]
  run ls -d "$FAKE_HOME"/.config.bak.*
  [ "$status" -ne 0 ] || { echo "~/.config was moved aside: $output"; return 1; }
}

@test "moves aside an entry of the same name instead of deleting it" {
  mkdir -p "$FAKE_HOME/.config/nvim"
  echo "keep me" > "$FAKE_HOME/.config/nvim/init.lua"
  run_setup
  [ "$FAKE_HOME/.config/nvim" -ef "$REPO/config/nvim" ]
  local rescued
  rescued="$(cat "$FAKE_HOME"/.config/nvim.bak.*/init.lua 2>/dev/null)"
  [ "$rescued" = "keep me" ] || { echo "pre-existing content was destroyed"; return 1; }
}

@test "moves aside a file standing where ~/.config belongs" {
  echo "keep me" > "$FAKE_HOME/.config"
  run_setup
  [ "$FAKE_HOME/.config/zsh" -ef "$REPO/config/zsh" ]
  assert_equal "$(cat "$FAKE_HOME"/.config.bak.*)" "keep me"
}

@test "creates ~/.ssh private to its owner, with our config linked" {
  run_setup
  [ ! -L "$FAKE_HOME/.ssh" ] || { echo "~/.ssh is a link"; return 1; }
  assert_equal "$(mode_of "$FAKE_HOME/.ssh")" "drwx------" "the mode of ~/.ssh"
  [ -L "$FAKE_HOME/.ssh/config" ]
  [ "$FAKE_HOME/.ssh/config" -ef "$REPO/ssh/config" ]
}

@test "creates an ssh config-local for machine-specific overrides" {
  run_setup
  [ -f "$FAKE_HOME/.ssh/config-local" ]
  [ ! -e "$REPO/ssh/config-local" ] || { echo "it was written into the clone"; return 1; }
}

@test "keeps what is already in ~/.ssh, and its mode" {
  mkdir -p "$FAKE_HOME/.ssh"
  chmod 750 "$FAKE_HOME/.ssh"
  echo "example.com ssh-ed25519 AAAA" > "$FAKE_HOME/.ssh/known_hosts"
  echo "Host old" > "$FAKE_HOME/.ssh/config"
  run_setup
  assert_equal "$(cat "$FAKE_HOME/.ssh/known_hosts")" "example.com ssh-ed25519 AAAA"
  assert_equal "$(cat "$FAKE_HOME"/.ssh/config.bak.*)" "Host old"
  [ "$FAKE_HOME/.ssh/config" -ef "$REPO/ssh/config" ]
  assert_equal "$(mode_of "$FAKE_HOME/.ssh")" "drwxr-x---" "the mode of ~/.ssh"
}

@test "leaves an ssh directory holding a private key alone" {
  # Where something else manages ssh -- a corporate setup, say -- its config is
  # what names the key, and moving that aside breaks authentication until it
  # is restored.
  mkdir -p "$FAKE_HOME/.ssh"
  printf 'PRIVATE KEY\n' > "$FAKE_HOME/.ssh/id_ed25519"
  echo "managed elsewhere" > "$FAKE_HOME/.ssh/config"
  run_setup
  [ ! -L "$FAKE_HOME/.ssh/config" ] || { echo "setup replaced a managed ssh config"; return 1; }
  [ "$(cat "$FAKE_HOME/.ssh/id_ed25519")" = "PRIVATE KEY" ]
  [ "$(cat "$FAKE_HOME/.ssh/config")" = "managed elsewhere" ]
}

# ------------------------------------------------------------------ ~/.claude

@test "links what git tracks under claude, inside a real ~/.claude" {
  run_setup
  [ -d "$FAKE_HOME/.claude" ]
  [ ! -L "$FAKE_HOME/.claude" ] || { echo "~/.claude is a link"; return 1; }
  local entry linked=0
  for entry in $(git -C "$REPO" ls-files -- claude | cut -d/ -f2 | sort -u); do
    [ -f "$REPO/claude/$entry" ] || continue
    [ -L "$FAKE_HOME/.claude/$entry" ] || { echo "$entry is not linked"; return 1; }
    [ "$FAKE_HOME/.claude/$entry" -ef "$REPO/claude/$entry" ] \
      || { echo "$entry points somewhere else"; return 1; }
    linked=$((linked + 1))
  done
  # The two files Claude Code reads in every session, whatever else is added.
  [ "$FAKE_HOME/.claude/CLAUDE.md" -ef "$REPO/claude/CLAUDE.md" ]
  [ "$FAKE_HOME/.claude/settings.json" -ef "$REPO/claude/settings.json" ]
  [ "$linked" -ge 2 ] || { echo "only $linked files were linked"; return 1; }
}

@test "a folder under claude is a real folder, holding a link for each entry" {
  make_clone
  run_setup
  local dir
  for dir in skills agents; do
    [ -d "$FAKE_HOME/.claude/$dir" ]
    [ ! -L "$FAKE_HOME/.claude/$dir" ] || { echo "~/.claude/$dir is a link"; return 1; }
  done
  [ -L "$FAKE_HOME/.claude/skills/tidy" ]
  [ "$FAKE_HOME/.claude/skills/tidy" -ef "$CLONE/claude/skills/tidy" ]
  [ -L "$FAKE_HOME/.claude/agents/reviewer.md" ]
  [ "$FAKE_HOME/.claude/agents/reviewer.md" -ef "$CLONE/claude/agents/reviewer.md" ]
}

@test "what is written into ~/.claude afterwards stays out of the clone" {
  # ~/.claude is where Claude Code keeps its sessions, its history and the
  # sign-in, and where a skill written on one machine goes. A link to the whole
  # directory, or to the whole of skills/, would put all of it in the working
  # tree of a public repo.
  make_clone
  run_setup
  echo '{"prompt": "private"}' > "$FAKE_HOME/.claude/history.jsonl"
  mkdir -p "$FAKE_HOME/.claude/projects/some-project" "$FAKE_HOME/.claude/skills/for-one-machine"
  echo "private" > "$FAKE_HOME/.claude/projects/some-project/session.jsonl"
  echo "# private" > "$FAKE_HOME/.claude/skills/for-one-machine/SKILL.md"
  echo "# private" > "$FAKE_HOME/.claude/agents/for-one-machine.md"
  assert_equal "$(cd "$CLONE" && find claude | LC_ALL=C sort | tr '\n' ' ')" \
    "claude claude/CLAUDE.md claude/agents claude/agents/reviewer.md claude/settings.json claude/skills claude/skills/tidy claude/skills/tidy/SKILL.md " \
    "the clone's claude directory"
}

@test "a name that is taken in ~/.claude is left as it is" {
  # Claude Code writes settings.json itself and reads no second file for one
  # machine. Moved aside, a machine's own settings would be moved aside again
  # on every run, with nowhere to keep them.
  make_clone
  mkdir -p "$FAKE_HOME/.claude/skills/tidy"
  echo '{"this machine": true}' > "$FAKE_HOME/.claude/settings.json"
  echo "# this machine's" > "$FAKE_HOME/.claude/skills/tidy/SKILL.md"
  run bash -c 'cd "$1" && HOME="$2" ./script/setup' _ "$CLONE" "$FAKE_HOME"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }

  [ ! -L "$FAKE_HOME/.claude/settings.json" ] || { echo "settings.json was replaced by a link"; return 1; }
  assert_equal "$(cat "$FAKE_HOME/.claude/settings.json")" '{"this machine": true}'
  [ ! -L "$FAKE_HOME/.claude/skills/tidy" ] || { echo "the skill was replaced by a link"; return 1; }
  assert_equal "$(cat "$FAKE_HOME/.claude/skills/tidy/SKILL.md")" "# this machine's"
  run ls -d "$FAKE_HOME"/.claude/*.bak.* "$FAKE_HOME"/.claude/skills/*.bak.*
  [ "$status" -ne 0 ] || { echo "moved aside: $output"; return 1; }

  # ...said out loud, and what is not taken is linked all the same.
  run bash -c 'cd "$1" && HOME="$2" ./script/setup' _ "$CLONE" "$FAKE_HOME"
  assert_contains "$output" "$FAKE_HOME/.claude/settings.json is this machine's own, leaving it alone"
  assert_contains "$output" "$FAKE_HOME/.claude/skills/tidy is this machine's own, leaving it alone"
  [ "$FAKE_HOME/.claude/CLAUDE.md" -ef "$CLONE/claude/CLAUDE.md" ]
  [ "$FAKE_HOME/.claude/agents/reviewer.md" -ef "$CLONE/claude/agents/reviewer.md" ]
}

@test "the repo's copy takes over once the machine's own is out of the way" {
  make_clone
  mkdir -p "$FAKE_HOME/.claude"
  echo '{"this machine": true}' > "$FAKE_HOME/.claude/settings.json"
  run_setup
  mv "$FAKE_HOME/.claude/settings.json" "$FAKE_HOME/.claude/settings.json.mine"
  run_setup
  [ "$FAKE_HOME/.claude/settings.json" -ef "$CLONE/claude/settings.json" ]
  assert_equal "$(cat "$FAKE_HOME/.claude/settings.json.mine")" '{"this machine": true}'
}

@test "a link in ~/.claude that leads nowhere is replaced" {
  # What a clone that has since moved leaves behind. There is nothing at the
  # end of it to keep.
  make_clone
  mkdir -p "$FAKE_HOME/.claude"
  ln -s "$FAKE_HOME/an-older-clone/claude/CLAUDE.md" "$FAKE_HOME/.claude/CLAUDE.md"
  run_setup
  [ "$FAKE_HOME/.claude/CLAUDE.md" -ef "$CLONE/claude/CLAUDE.md" ] \
    || { echo "still: $(readlink "$FAKE_HOME/.claude/CLAUDE.md")"; return 1; }
}

@test "a skill nobody has added is not linked" {
  make_clone
  mkdir -p "$CLONE/claude/skills/not-added-yet"
  echo "# a draft" > "$CLONE/claude/skills/not-added-yet/SKILL.md"
  run_setup
  [ ! -e "$FAKE_HOME/.claude/skills/not-added-yet" ] \
    || { echo "an untracked skill was linked"; return 1; }
  [ -L "$FAKE_HOME/.claude/skills/tidy" ]
}

# ------------------------------------------------- from the whole-directory layout

@test "a home linked to the clone's whole directories gets its files back" {
  make_whole_directory_home
  run_setup

  [ ! -L "$FAKE_HOME/.config" ] || { echo "~/.config is still a link"; return 1; }
  [ ! -L "$FAKE_HOME/.ssh" ]    || { echo "~/.ssh is still a link"; return 1; }

  # Other tools' files: same path from home, no longer inside the clone.
  assert_equal "$(cat "$FAKE_HOME/.config/some-other-tool/state")" "keep me"
  assert_equal "$(cat "$FAKE_HOME/.config/.hidden-state")" "hidden"
  assert_equal "$(cat "$FAKE_HOME/.ssh/known_hosts")" "example.com ssh-ed25519 AAAA"
  assert_equal "$(cat "$FAKE_HOME/.ssh/config-local")" "Host local"
  assert_equal "$(ls -A "$CLONE/config" | tr '\n' ' ')" "nvim starship.toml zsh " \
    "the clone's config directory"
  assert_equal "$(ls -A "$CLONE/ssh")" "config" "the clone's ssh directory"
  [ ! -L "$FAKE_HOME/.config/some-other-tool" ] \
    || { echo "another tool's directory was linked into the clone"; return 1; }

  # Ours: still in the clone, and reached through a link each.
  local entry
  for entry in .config/nvim .config/starship.toml .config/zsh .ssh/config; do
    [ -L "$FAKE_HOME/$entry" ] || { echo "$entry is not a link"; return 1; }
    [ "$FAKE_HOME/$entry" -ef "$CLONE/${entry#.}" ] \
      || { echo "$entry points somewhere else"; return 1; }
  done
  [ "$FAKE_HOME/.zshenv" -ef "$CLONE/config/zsh/.zshenv" ]

  assert_equal "$(mode_of "$FAKE_HOME/.ssh")" "drwx------" "the mode of ~/.ssh"
  run ls -d "$FAKE_HOME"/.*.migrating "$FAKE_HOME"/.*.bak.*
  [ "$status" -ne 0 ] || { echo "left behind: $output"; return 1; }
}

@test "an interrupted move out of the clone is picked up where it stopped" {
  make_whole_directory_home
  # One entry had already been moved when the earlier run died.
  mkdir -p "$FAKE_HOME/.config.migrating"
  mv "$CLONE/config/some-other-tool" "$FAKE_HOME/.config.migrating/some-other-tool"
  run_setup
  assert_equal "$(cat "$FAKE_HOME/.config/some-other-tool/state")" "keep me"
  assert_equal "$(cat "$FAKE_HOME/.config/.hidden-state")" "hidden"
  [ ! -e "$FAKE_HOME/.config.migrating" ]
}

@test "an ssh key that had been kept in the clone moves out with everything else" {
  # The private-key rule is about an ~/.ssh somebody else manages. One that is
  # a link into the clone is ours to rearrange, key or no key.
  make_whole_directory_home
  printf 'PRIVATE KEY\n' > "$FAKE_HOME/.ssh/id_ed25519"
  run_setup
  assert_equal "$(cat "$FAKE_HOME/.ssh/id_ed25519")" "PRIVATE KEY"
  [ ! -e "$CLONE/ssh/id_ed25519" ] || { echo "the key is still in the clone"; return 1; }
  [ "$FAKE_HOME/.ssh/config" -ef "$CLONE/ssh/config" ]
}
