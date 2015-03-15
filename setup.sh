#!/bin/sh

# Get our git submodules, recursively
git submodule update --init --recursive

for name in *; do
  target="$HOME/.$name"
  if [ "$name" != 'setup.sh' ] && [ "$name" != 'README.md' ] && [ "$name" != 'LICENSE' ]; then
    if [ -e "$target" ]; then
      if [ ! -L "$target" ]; then
        echo "WARNING: $target exists but is not a symlink."
      fi
    else
      echo "Creating $target"
      ln -s "$PWD/$name" "$target"
    fi
  fi
done