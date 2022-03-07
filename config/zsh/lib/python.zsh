#!/usr/bin/env zsh

export PYENV_ROOT="$XDG_DATA_HOME/pyenv"

if [[ -x "$(command -v pyenv)" ]]; then
  # nodenv init --path
  export PATH="$PYENV_ROOT/shims:${PATH}"
  # nodenv init -
  export PYENV_SHELL=zsh
  source '/opt/homebrew/Cellar/pyenv/2.2.4-1/libexec/../completions/pyenv.zsh'
  command pyenv rehash 2>/dev/null
  pyenv() {
    local command
    command="${1:-}"
    if [ "$#" -gt 0 ]; then
      shift
    fi

    case "$command" in
    activate|deactivate|rehash|shell)
      eval "$(pyenv "sh-$command" "$@")"
      ;;
    *)
      command pyenv "$command" "$@"
      ;;
    esac
  }
fi
