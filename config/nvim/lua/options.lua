-- Settings. Only what earns its place in an editor used for commit messages,
-- config files, and reading code someone else is writing.

local opt = vim.opt

opt.termguicolors = true -- replaces NVIM_TUI_ENABLE_TRUE_COLOR, dead since 0.1
opt.background = "dark"

opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes" -- gitsigns would otherwise shift the text on first change
opt.scrolloff = 3

opt.ignorecase = true
opt.smartcase = true -- ... unless the search itself contains a capital

opt.undofile = true -- undo history survives closing the file
opt.splitbelow = true
opt.splitright = true

-- ripgrep comes from the Brewfile, and is what fzf-lua shells out to as well.
-- Guarded because a missing rg makes :grep silently return nothing.
if vim.fn.executable("rg") == 1 then
  opt.grepprg = "rg --vimgrep"
  opt.grepformat = "%f:%l:%c:%m"
end

-- Nothing here uses the python, ruby, node or perl providers. Disabling them
-- skips the probe at startup and keeps :checkhealth honest. This replaces two
-- copies of a g:python_host_prog that pointed at an Intel Homebrew prefix and
-- a python2 that has been end-of-life since 2020.
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
