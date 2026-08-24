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

cached_init mise mise activate zsh && source $REPLY
