#!/usr/bin/env zsh

# Skip when the base layer already initialised SDKMAN; sourcing its init twice
# only duplicates PATH entries.
if (( ! $+functions[sdk] )); then
  export SDKMAN_DIR="$HOME/.sdkman"

  if [ -f "$SDKMAN_DIR/bin/sdkman-init.sh" ]; then
    source "$SDKMAN_DIR/bin/sdkman-init.sh"
  fi
fi
