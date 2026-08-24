-- Mappings. `gc` for comments and `]q`/`[b` for the quickfix and buffer lists
-- are Neovim's own; `ga` for alignment and ys/ds/cs for surround come from
-- mini. What is left is the picker.

local map = vim.keymap.set

-- <leader><space> was bound to an MRU picker whose plugin no longer resolves.
-- Files is the nearest surviving equivalent, with recent files one key away.
map("n", "<leader><space>", "<cmd>FzfLua files<cr>", { desc = "Find file" })
map("n", "<leader>h", "<cmd>FzfLua oldfiles<cr>", { desc = "Recent files" })
map("n", "<leader>b", "<cmd>FzfLua buffers<cr>", { desc = "Buffers" })
map("n", "<leader>/", "<cmd>FzfLua live_grep<cr>", { desc = "Grep in project" })
map("n", "<leader>d", "<cmd>FzfLua diagnostics_document<cr>", { desc = "Diagnostics" })

-- Clear search highlighting, which nothing else offers a way out of.
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
