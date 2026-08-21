#!/usr/bin/env zsh

# pyenv
export PYENV_ROOT="$XDG_DATA_HOME/pyenv"

# Any Python index config the base layer exports (PIP_CONFIG_FILE,
# UV_CONFIG_FILE, WORKON_HOME) is left alone.
if (( $+commands[pyenv] )); then
  # pyenv init --path. Only front PATH once shims exist: with no version
  # installed there is nothing to shim, and an empty dir here would shadow
  # whatever python the base layer arranged.
  [[ -d "$PYENV_ROOT/shims" ]] && export PATH="$PYENV_ROOT/shims:${PATH}"
  # pyenv init -
  export PYENV_SHELL=zsh
  # Completions ship with the Homebrew formula; the path differs elsewhere
  for _pyenv_completions in \
    "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/pyenv/completions/pyenv.zsh" \
    "$PYENV_ROOT/completions/pyenv.zsh"; do
    [[ -r "$_pyenv_completions" ]] && source "$_pyenv_completions" && break
  done
  unset _pyenv_completions
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

# pyenv-virtualenv. Guarded: without pyenv on PATH the precmd hook below fails
# on every prompt.
if (( $+commands[pyenv] )) && [[ -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]]; then
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
fi
