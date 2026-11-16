#!/usr/bin/env zsh

# mise manages runtimes here, in place of nodenv, node-build, pyenv,
# pyenv-virtualenv and sdkman.
#
# Nothing stands down per tool, and nothing needs to. Where a base layer owns a
# runtime it does so with shell functions -- nvm wraps node and npm, sdkman
# wraps sdk -- and a function is found before anything mise puts on PATH, so
# those keep winning without being asked to. The global config declares no
# tools, so mise claims nothing on its own either.
(( $+commands[mise] )) || return

cached_init mise mise activate zsh || return

# The script opens by exporting the PATH of the shell that generated it: mise's
# record of what PATH was before mise touched it. From a cache that is some
# earlier shell's PATH, and mise appends every directory in it that this shell
# lacks. Without the line, the script takes this shell's PATH for the record,
# which is what running `mise activate` here would have given it.
__dotfiles_lines="$(<$REPLY)"
__dotfiles_lines=("${(@f)__dotfiles_lines}")
eval "${(F)${(@)__dotfiles_lines:#export __MISE_ORIG_PATH=*}}"
unset __dotfiles_lines
