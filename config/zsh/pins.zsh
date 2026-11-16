#!/usr/bin/env zsh

# The commit each piece of third-party shell code runs at. All of it is sourced
# into every shell, so it changes when a line here does, and not with whatever
# was newest on the day a machine was set up.
#
# One line each: repository on GitHub, commit, and the branch that commit is
# on. Renovate reads these lines (see .github/renovate.json) and proposes a new
# commit when the branch moves, so keep to the shape.
#
# Changing a line is all it takes. A new machine installs at the commit, and
# the autoloaded sync_pins moves an existing one on its next shell.
typeset -gA DOTFILES_PINS=(
  zdharma-continuum/zinit                 d7b10fcab51ea034aa7df5d241604b3e6bf46449  # main
  MichaelAquilina/zsh-you-should-use      5f3d129864ee4505043d88c3486224f1d75b692e  # master
  zsh-users/zsh-autosuggestions           85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5  # master
  zsh-users/zsh-completions               989b23277ab33e8d5e82df6aed936e846db9d8b8  # master
  zsh-users/zsh-history-substring-search  a0bdb0d47dbaba31dba2db7af8c48a5d9c74049a  # master
)
