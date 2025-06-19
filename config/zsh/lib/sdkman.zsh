#!/usr/bin/env zsh

export SDKMAN_DIR="$HOME/.sdkman"

if [ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
  source "$HOME/.sdkman/bin/sdkman-init.sh"
fi
