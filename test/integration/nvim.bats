#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../helpers/common'

# Neovim's config is Lua and its plugins install themselves, so "it parses" says
# almost nothing. These provision a hermetic data directory once, then assert the
# editor that comes out of it actually works: the colourscheme applied, parsers
# built, highlighting attached, and the surround keys still tpope's.
#
# The data directory is keyed on the lockfile and the parser list and cached in
# $TMPDIR, because building eleven parsers takes about a minute. Delete it to
# force a fresh provision.

setup_file() {
  command -v nvim >/dev/null 2>&1 || return 0

  local key
  key="$(cat "$REPO/config/nvim/lazy-lock.json" "$REPO/config/nvim/lua/parsers.lua" 2>/dev/null \
    | shasum | cut -c1-12)"
  export NVIM_DATA="${TMPDIR:-/tmp}/dotfiles-nvim-$key"
  export NVIM_HOME="$NVIM_DATA/home"

  if [ ! -d "$NVIM_DATA/nvim/lazy/lazy.nvim" ]; then
    mkdir -p "$NVIM_HOME"
    HOME="$NVIM_HOME" XDG_CONFIG_HOME="$REPO/config" XDG_DATA_HOME="$NVIM_DATA" \
      XDG_STATE_HOME="$NVIM_DATA/state" XDG_CACHE_HOME="$NVIM_DATA/cache" \
      _timeout 900 "$REPO/script/after-setup" >"$NVIM_DATA/provision.log" 2>&1 || true
  fi
}

# Run lua in a headless nvim against the repo's config and the cached data dir.
probe() {
  HOME="$NVIM_HOME" XDG_CONFIG_HOME="$REPO/config" XDG_DATA_HOME="$NVIM_DATA" \
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

@test "nvim: gotham is the colourscheme and space is the leader" {
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
    io.stdout:write(("ft=%s tw=%d spell=%s"):format(
      vim.bo.filetype, vim.bo.textwidth, tostring(vim.wo.spell)))' -c qa
  echo "$output" | grep -q "ft=gitcommit tw=72 spell=true" \
    || { echo "the gitcommit ftplugin did not apply: $output"; return 1; }
}

@test "nvim: the language providers stay disabled" {
  # Replaces two copies of a python2 host prog pointing at an Intel prefix.
  run probe -c 'lua io.stdout:write(("py=%s rb=%s node=%s perl=%s"):format(
    tostring(vim.g.loaded_python3_provider), tostring(vim.g.loaded_ruby_provider),
    tostring(vim.g.loaded_node_provider), tostring(vim.g.loaded_perl_provider)))' -c qa
  echo "$output" | grep -q "py=0 rb=0 node=0 perl=0" || { echo "$output"; return 1; }
}
