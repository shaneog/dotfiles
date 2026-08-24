-- Five repositories, replacing twenty-three.
--
-- Gone because Neovim does it now: editorconfig-vim, vim-commentary,
-- vim-unimpaired, vim-repeat. Gone because the tooling is not on these machines:
-- vim-go, vim-jsonnet, nginx.vim, vim-haml, and the Rails cluster. Gone because
-- something here does it better: vim-polyglot (treesitter), vim-gitgutter
-- (gitsigns), airline (mini.statusline), vim-surround and vim-easy-align (mini),
-- fzf.vim with fzf-filemru and vim-ripgrep (fzf-lua). Solarized was never used;
-- gotham is the colourscheme, and has been since 2016.

local parsers = require("parsers")

return {
  -- Colourscheme, the same one as the Terminal profile and tmux. It predates
  -- treesitter, so highlighting lands on Neovim's default capture links rather
  -- than fine-grained groups -- which is fine, and is what it looked like
  -- before.
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
      -- Parsers are installed by script/after-setup, not here. Calling install()
      -- on every start is both noisy in a headless run and racy: two concurrent
      -- installs of the same parser collide renaming their temp directories,
      -- which is how yaml failed to build while the run reported success.
      -- :TSInstall and :TSUpdate remain for doing it by hand.

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

  -- One picker, replacing three plugins. The old fzf.vim spec pointed at
  -- $HOME/.zplug/repos/junegunn/fzf, which stopped existing when the shell
  -- moved to zinit, so that picker has been broken for years. fzf, fd and
  -- ripgrep all come from the Brewfile.
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
      -- tpope's keys on purpose: ys/ds/cs is twenty years of muscle memory, and
      -- mini's own sa/sd/sr would be a silent retraining. This is mini's
      -- documented vim-surround recipe.
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
