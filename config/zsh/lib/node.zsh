#!/usr/bin/env zsh

export NODENV_ROOT="$XDG_DATA_HOME/nodenv"

# Use XDG_DATA_HOME for npm cache
export NPM_CONFIG_CACHE="$XDG_DATA_HOME/npm"

# https://github.com/nodenv/node-build-update-defs
export NODE_BUILD_DEFINITIONS="/opt/homebrew/opt/node-build-update-defs/share/node-build"

# nodenv init -
if [[ -x "$(command -v nodenv)" ]]; then
  export PATH="$NODENV_ROOT/shims:${PATH}"
  export NODENV_SHELL=zsh
  source '/opt/homebrew/opt/nodenv/completions/nodenv.zsh'
  command nodenv rehash 2>/dev/null
  nodenv() {
    local command
    command="${1:-}"
    if [ "$#" -gt 0 ]; then
      shift
    fi

    case "$command" in
      rehash|shell)
        eval "$(nodenv "sh-$command" "$@")" ;;
      *)
        command nodenv "$command" "$@" ;;
    esac
  }
fi
