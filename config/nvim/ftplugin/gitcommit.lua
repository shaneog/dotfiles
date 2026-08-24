-- Commit messages are most of what this editor is opened for, and this repo's
-- convention is a Conventional Commits subject with a body that explains why.
-- Both of those are easier with the ruler in the right place.

vim.opt_local.textwidth = 72 -- git's own convention for the body
vim.opt_local.colorcolumn = "73"
vim.opt_local.spell = true
vim.opt_local.spelllang = "en_gb"

-- Start on the subject line rather than wherever the last buffer was.
vim.api.nvim_win_set_cursor(0, { 1, 0 })
