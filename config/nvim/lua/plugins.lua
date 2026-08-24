-- Five repositories. Anything Neovim provides itself -- commenting, editorconfig,
-- the ]q and [b motions -- is not a plugin here, and neither is support for a
-- language whose tooling is not installed.

local parsers = require("parsers")

return {
  -- The same colorscheme as the Terminal profile and tmux. Written before
  -- treesitter, so highlighting resolves through Neovim's default capture links
  -- rather than fine-grained groups.
  {
    "whatyouhide/vim-gotham",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("gotham")
    end,
  },

  -- Highlighting and indentation. The main branch requires 0.12 and, unlike the
  -- old master branch, does not enable highlighting itself: that is what the
  -- autocmd below is for. Without it everything silently stays unhighlighted.
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      -- Parsers are installed by script/after-setup, not here: install() on
      -- every start is noisy in a headless run, and two concurrent installs of
      -- the same parser collide renaming their temp directories while still
      -- reporting success. :TSInstall and :TSUpdate do it by hand.

      -- Shell dialects share bash's parser; .zsh files are most of this repo.
      for ft, parser in pairs(parsers) do
        vim.treesitter.language.register(parser, ft)
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = vim.tbl_keys(parsers),
        callback = function()
          -- pcall: a parser still downloading is not worth an error on every
          -- buffer the first time a machine is set up.
          pcall(vim.treesitter.start)
        end,
      })
    end,
  },

  -- Signs in the gutter and hunk navigation, replacing vim-gitgutter.
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },

  -- fzf, fd and ripgrep all come from the Brewfile, so this picker has no
  -- vendored binary and no path of its own to keep in step with the shell.
  {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    opts = {},
  },

  -- surround, align and the statusline, from one repository.
  {
    "nvim-mini/mini.nvim",
    version = false,
    lazy = false,
    config = function()
      -- tpope's keys on purpose: mini's own sa/sd/sr would be a silent
      -- retraining. This is mini's documented vim-surround recipe.
      require("mini.surround").setup({
        mappings = {
          add = "ys",
          delete = "ds",
          replace = "cs",
          find = "",
          find_left = "",
          highlight = "",
          update_n_lines = "",
          suffix_last = "",
          suffix_next = "",
        },
        search_method = "cover_or_next",
      })
      vim.keymap.set("x", "S", [[:<C-u>lua MiniSurround.add('visual')<cr>]], {
        silent = true,
        desc = "Surround selection",
      })

      -- ga, the same mapping vim-easy-align had.
      require("mini.align").setup()

      require("mini.statusline").setup({ use_icons = true })
    end,
  },
}
