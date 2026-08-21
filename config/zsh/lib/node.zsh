#!/usr/bin/env zsh

# The base layer may manage Node through nvm, wrapping node/npm/nvm/pnpm in
# shell functions. Those take precedence over nodenv's shims whatever we put on
# PATH, and its npm wrapper is what points npm at the private registry, so hand
# Node over wholesale rather than half-shadowing it.
if (( $+functions[nvm] + $+functions[node] + $+functions[npm] )); then
  return
fi

export NODENV_ROOT="$XDG_DATA_HOME/nodenv"

# Use XDG_DATA_HOME for npm cache
export NPM_CONFIG_CACHE="$XDG_DATA_HOME/npm"

# https://github.com/nodenv/node-build-update-defs
export NODE_BUILD_DEFINITIONS="/opt/homebrew/opt/node-build-update-defs/share/node-build"

# nodenv init -
if [[ -x "$(command -v nodenv)" ]]; then
  export PATH="$NODENV_ROOT/shims:${PATH}"
  export NODENV_SHELL=zsh
  command nodenv rehash 2>/dev/null
  nodenv() {
    local command
    command="${1:-}"
    if [ "$#" -gt 0 ]; then
      shift
    fi

    case "$command" in
    rehash|shell)
      eval "$(nodenv "sh-$command" "$@")";;
    *)
      command nodenv "$command" "$@";;
    esac
  }
fi
