#!/usr/bin/env zsh

export PYENV_ROOT="$XDG_DATA_HOME/pyenv"

if [[ -x "$(command -v pyenv)" ]]; then
  # pyenv init --path
  export PATH="$PYENV_ROOT/shims:${PATH}"
  # pyenv init -
  export PYENV_SHELL=zsh
  source "/opt/homebrew/opt/pyenv/completions/pyenv.zsh"
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
