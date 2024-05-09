#!/usr/bin/env zsh

# pyenv
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

# pyenv-virtualenv
export PATH="$PYENV_ROOT/plugins/pyenv-virtualenv/shims:${PATH}";
export PYENV_VIRTUALENV_INIT=1;
_pyenv_virtualenv_hook() {
  local ret=$?
  if [ -n "${VIRTUAL_ENV-}" ]; then
    eval "$(pyenv sh-activate --quiet || pyenv sh-deactivate --quiet || true)" || true
  else
    eval "$(pyenv sh-activate --quiet || true)" || true
  fi
  return $ret
};
typeset -g -a precmd_functions
if [[ -z $precmd_functions[(r)_pyenv_virtualenv_hook] ]]; then
  precmd_functions=(_pyenv_virtualenv_hook $precmd_functions);
fi
