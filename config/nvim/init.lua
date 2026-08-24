-- Neovim configuration.
--
-- Lean by intent: this is $EDITOR -- commit messages, config edits, a quick
-- look at a file -- not a second IDE. So anything Neovim now does on its own is
-- left to Neovim rather than reproduced by a plugin: `gc` commenting,
-- editorconfig support and the `]q`/`[b` motions all ship in the editor.

-- Leader has to be set before lazy.nvim maps anything against it.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("options")

-- lazy.nvim bootstraps itself on first start. Plugins live under
-- stdpath("data"), so nothing a plugin manager writes lands inside this repo --
-- which is why there is no longer a `plugged` directory to gitignore.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("could not clone lazy.nvim:\n" .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = require("plugins"),
  install = { colorscheme = { "gotham" } },
  change_detection = { notify = false },
  -- Committed, so a new machine installs the versions this one is running.
  lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json",
})

require("keymaps")
