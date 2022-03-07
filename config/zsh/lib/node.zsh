#!/usr/bin/env zsh

export NODENV_ROOT="$XDG_DATA_HOME/nodenv"

# Use XDG_DATA_HOME for npm cache
export NPM_CONFIG_CACHE="$XDG_DATA_HOME/npm"

# nodenv init -
if [[ -x "$(command -v nodenv)" ]]; then
  export PATH="$NODENV_ROOT/shims:${PATH}"
  export NODENV_SHELL=zsh
  source '/opt/homebrew/Cellar/nodenv/1.4.0/libexec/../completions/nodenv.zsh'
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
