-- Settings. Only what earns its place in an editor used for commit messages,
-- config files, and reading code someone else is writing.

local opt = vim.opt

-- 24-bit color where the terminal says it has it. Terminal.app sets
-- COLORTERM=truecolor; anything that does not say so keeps 256-color
-- rendering rather than being sent escapes it cannot draw.
opt.termguicolors = vim.env.COLORTERM == "truecolor" or vim.env.COLORTERM == "24bit"
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
-- skips the probe at startup and keeps :checkhealth honest.
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
