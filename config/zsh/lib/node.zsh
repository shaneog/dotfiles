#!/usr/bin/env zsh

# The base layer may manage Node through nvm, wrapping node/npm/nvm in shell
# functions. Its npm wrapper is what points npm at a private registry, and its
# cache location is its own business, so hand Node over wholesale rather than
# reaching into it. Runtimes are otherwise mise's job now; see mise.zsh.
if (( $+functions[nvm] + $+functions[node] + $+functions[npm] )); then
  return
fi

# Keep npm's cache out of the home directory.
export NPM_CONFIG_CACHE="$XDG_DATA_HOME/npm"
