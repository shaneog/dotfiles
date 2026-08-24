-- Filetype to treesitter parser, for the filetypes Neovim has no parser for.
--
-- 0.12 bundles c, lua, markdown, query, vim and vimdoc. Everything a dotfiles
-- repo is actually made of -- shell, zsh, yaml, json, toml, git -- has to be
-- installed, which is the only reason nvim-treesitter is here at all.
--
-- Keys are filetypes and values are parsers, because the two names differ often
-- enough to get wrong: a shell script is filetype `sh`, and `.gitconfig` is
-- filetype `gitconfig`, parsed by `git_config`.

return {
  sh = "bash",
  bash = "bash",
  zsh = "bash",
  yaml = "yaml",
  json = "json",
  jsonc = "json",
  toml = "toml",
  make = "make",
  diff = "diff",
  gitcommit = "gitcommit",
  gitconfig = "git_config",
  gitignore = "gitignore",
  gitrebase = "git_rebase",
  ssh_config = "ssh_config",
  -- No tmux parser exists upstream; Neovim's own syntax/tmux.vim covers it.
}
