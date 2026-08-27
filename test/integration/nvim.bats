#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# Neovim's config is Lua and its plugins install themselves, so "it parses" says
# almost nothing. These provision a hermetic data directory once, then assert the
# editor that comes out of it actually works: the colorscheme applied, parsers
# built, highlighting attached, and the surround keys still tpope's.
#
# The data directory is cached in $TMPDIR, because building eleven parsers takes
# about a minute. Delete it to force a fresh provision.
#
# The key covers only what provisioning depends on -- the lockfile, the plugin
# specs, the parser list, and the bootstrap -- not every file under config/nvim.
# Hashing all of them meant editing an option, which installs nothing, threw the
# cache away and rebuilt every parser.

setup_file() {
  command -v nvim >/dev/null 2>&1 || return 0

  local key
  key="$(cat "$REPO/config/nvim/init.lua" "$REPO/config/nvim/lua/plugins.lua" \
             "$REPO/config/nvim/lua/parsers.lua" "$REPO/config/nvim/lazy-lock.json" \
             2>/dev/null | shasum | cut -c1-12)"
  export NVIM_DATA="${TMPDIR:-/tmp}/dotfiles-nvim-$key"
  export NVIM_HOME="$NVIM_DATA/home"
  # A *copy* of the config, not the repo. lazy.nvim writes lazy-lock.json next to
  # the config it loaded, and a provision into an empty data dir clones lazy.nvim
  # from its stable branch -- so pointing at the repo let a test run rewrite a
  # tracked file with whichever lazy commit was stable that day.
  export NVIM_CONFIG="$NVIM_DATA/config"

  # The config is re-copied every run even when the data directory is reused:
  # the copy is what nvim reads, so a cached one is a stale one, and a change to
  # an option would be tested against the previous version of itself.
  mkdir -p "$NVIM_HOME" "$NVIM_CONFIG"
  rm -rf "$NVIM_CONFIG/nvim"
  cp -R "$REPO/config/nvim" "$NVIM_CONFIG/nvim"

  if [ ! -d "$NVIM_DATA/nvim/lazy/lazy.nvim" ]; then
    HOME="$NVIM_HOME" XDG_CONFIG_HOME="$NVIM_CONFIG" XDG_DATA_HOME="$NVIM_DATA" \
      XDG_STATE_HOME="$NVIM_DATA/state" XDG_CACHE_HOME="$NVIM_DATA/cache" \
      _timeout 900 "$REPO/script/after-setup" >"$NVIM_DATA/provision.log" 2>&1 || true
  fi
}

# Run lua in a headless nvim against the repo's config and the cached data dir.
probe() {
  HOME="$NVIM_HOME" XDG_CONFIG_HOME="$NVIM_CONFIG" XDG_DATA_HOME="$NVIM_DATA" \
    XDG_STATE_HOME="$NVIM_DATA/state" XDG_CACHE_HOME="$NVIM_DATA/cache" \
    TERM=xterm-256color _timeout 120 nvim --headless "$@" </dev/null 2>&1
}

setup() {
  command -v nvim >/dev/null 2>&1 || skip "neovim is not installed"
  [ -d "${NVIM_DATA:-}/nvim/lazy/lazy.nvim" ] \
    || { echo "provisioning failed; see $NVIM_DATA/provision.log"; return 1; }
}

@test "nvim: the config loads without complaining" {
  run probe -c 'lua io.stdout:write("loaded")' -c qa
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  # Anything else on the way through is an error worth seeing.
  local noise
  noise="$(echo "$output" | grep -v '^loaded$' | grep '[[:alpha:]]' || true)"
  [ -z "$noise" ] || { echo "startup was not quiet: $noise"; return 1; }
}

@test "nvim: gotham is the colorscheme and space is the leader" {
  run probe -c 'lua io.stdout:write(("colors=%s leader=%q"):format(vim.g.colors_name, vim.g.mapleader))' -c qa
  echo "$output" | grep -q "colors=gotham" || { echo "$output"; return 1; }
  echo "$output" | grep -q 'leader=" "' || { echo "$output"; return 1; }
}

@test "nvim: treesitter highlights a zsh file" {
  # The flagship assertion. nvim-treesitter's main branch needs tree-sitter-cli
  # to build parsers, and without it install() reports success and installs
  # nothing -- so highlighting silently never happens. Asserting that a parser
  # is configured would not have caught that; asserting the highlighter attached
  # does.
  run probe "$REPO/config/zsh/lib/mise.zsh" -c 'lua
    local buf = vim.api.nvim_get_current_buf()
    vim.wait(5000, function() return vim.treesitter.highlighter.active[buf] ~= nil end)
    io.stdout:write(("ft=%s parser=%s attached=%s"):format(
      vim.bo.filetype,
      tostring(vim.treesitter.language.get_lang(vim.bo.filetype)),
      tostring(vim.treesitter.highlighter.active[buf] ~= nil)))' -c qa
  echo "$output" | grep -q "ft=zsh parser=bash attached=true" \
    || { echo "treesitter is not highlighting zsh: $output"; return 1; }
}

@test "nvim: every parser in the list actually built" {
  run probe -c 'lua
    local seen, want = {}, {}
    for _, p in pairs(require("parsers")) do
      if not seen[p] then seen[p] = true; want[#want + 1] = p end
    end
    local got = {}
    for _, p in ipairs(require("nvim-treesitter").get_installed("parsers")) do got[p] = true end
    local missing = {}
    for _, p in ipairs(want) do if not got[p] then missing[#missing + 1] = p end end
    table.sort(missing)
    io.stdout:write(("want=%d missing=%s"):format(#want, #missing == 0 and "none" or table.concat(missing, ",")))' -c qa
  echo "$output" | grep -q "missing=none" \
    || { echo "some parsers never built: $output"; return 1; }
}

@test "nvim: surround keeps tpope's keys, not mini's defaults" {
  # mini.surround defaults to sa/sd/sr. Those are remapped on purpose, and a
  # silent revert to the defaults would retrain muscle memory without warning.
  run probe -c 'lua
    local function has(lhs) return vim.fn.maparg(lhs, "n") ~= "" end
    io.stdout:write(("ys=%s ds=%s cs=%s sa=%s"):format(
      tostring(has("ys")), tostring(has("ds")), tostring(has("cs")), tostring(has("sa"))))' -c qa
  echo "$output" | grep -q "ys=true ds=true cs=true sa=false" \
    || { echo "surround mappings are wrong: $output"; return 1; }
}

@test "nvim: the picker and the built-in commenting are both there" {
  run probe -c 'lua
    io.stdout:write(("fzflua=%s gc=%s"):format(
      tostring(vim.fn.exists(":FzfLua") == 2),
      tostring(vim.fn.maparg("gc", "n") ~= "" or vim.fn.mapcheck("gc", "n") ~= "")))' -c qa
  echo "$output" | grep -q "fzflua=true gc=true" || { echo "$output"; return 1; }
}

@test "nvim: a commit message buffer is set up for writing one" {
  run probe "$NVIM_DATA/COMMIT_EDITMSG" -c 'lua
    io.stdout:write(("ft=%s tw=%d spell=%s lang=%s"):format(
      vim.bo.filetype, vim.bo.textwidth, tostring(vim.wo.spell), vim.bo.spelllang))' -c qa
  # en_us is deliberate, and matches the locale .zprofile sets.
  echo "$output" | grep -q "ft=gitcommit tw=72 spell=true lang=en_us" \
    || { echo "the gitcommit ftplugin did not apply: $output"; return 1; }
}

@test "nvim: the language providers stay disabled" {
  # Nothing here uses them, and a probe for a missing interpreter is startup
  # cost for nothing.
  run probe -c 'lua io.stdout:write(("py=%s rb=%s node=%s perl=%s"):format(
    tostring(vim.g.loaded_python3_provider), tostring(vim.g.loaded_ruby_provider),
    tostring(vim.g.loaded_node_provider), tostring(vim.g.loaded_perl_provider)))' -c qa
  echo "$output" | grep -q "py=0 rb=0 node=0 perl=0" || { echo "$output"; return 1; }
}

@test "nvim: 24-bit colour is enabled only when the terminal claims it" {
  # The same decision tmux makes, and for the same reason: sending 24-bit escapes
  # to a terminal that only advertises 256 is what an older client over ssh gets.
  COLORTERM=truecolor run probe -c 'lua io.stdout:write("tgc=" .. tostring(vim.o.termguicolors))' -c qa
  echo "$output" | grep -q "tgc=true" \
    || { echo "COLORTERM=truecolor did not enable termguicolors: $output"; return 1; }

  COLORTERM= run probe -c 'lua io.stdout:write("tgc=" .. tostring(vim.o.termguicolors))' -c qa
  echo "$output" | grep -q "tgc=false" \
    || { echo "termguicolors was on with no COLORTERM: $output"; return 1; }
}

@test "nvim: undo history survives closing the file" {
  # undofile. Asserted by undoing an edit in a *later* nvim: without the option
  # the second one starts with an empty undo tree and the u does nothing.
  local f="$BATS_TEST_TMPDIR/undome.txt"
  printf 'first\nsecond\n' > "$f"
  run probe -c "edit $f" -c 'normal! ggdd' -c 'write' -c qa
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  grep -q '^first$' "$f" && { echo "the edit did not happen, so the undo proves nothing"; return 1; }

  run probe -c "edit $f" -c 'normal! u' -c 'write' -c qa
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  grep -q '^first$' "$f" \
    || { echo "undo did not reach across sessions: $(cat "$f")"; return 1; }
}

@test "nvim: :grep respects ignore files" {
  # grepprg. Neovim's own default is already `rg --vimgrep -uu`, and -uu means
  # "search ignored and hidden files too" -- so what this repo's setting actually
  # changes is that :grep skips what an ignore file excludes. A search that finds
  # everything either way would not notice the setting at all.
  local hay="$BATS_TEST_TMPDIR/haystack"
  mkdir -p "$hay"
  printf 'the needle is here\n' > "$hay/visible.txt"
  printf 'the needle is here too\n' > "$hay/ignored.txt"
  # .ignore rather than .gitignore: ripgrep honours it with or without a git repo.
  printf 'ignored.txt\n' > "$hay/.ignore"

  run probe -c "silent grep! needle $hay" \
    -c 'lua local q = vim.fn.getqflist()
        local names = {}
        for _, e in ipairs(q) do names[#names + 1] = vim.fn.fnamemodify(e.filename or vim.api.nvim_buf_get_name(e.bufnr), ":t") end
        io.stdout:write("hits=" .. table.concat(names, ","))' -c qa
  echo "$output" | grep -q "visible.txt" \
    || { echo ":grep found nothing at all: $output"; return 1; }
  echo "$output" | grep -q "ignored.txt" \
    && { echo ":grep searched an ignored file, so -uu is still in effect: $output"; return 1; }
  return 0
}
