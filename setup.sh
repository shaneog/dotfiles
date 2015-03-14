#!/bin/sh

# Get our git submodules, recursively
git submodule update --init --recursive

for name in *; do
  target="$HOME/.$name"
  if [ "$name" != 'setup.sh' ]; then
    echo "Creating $target"
    ln -s "$PWD/$name" "$target"
  fi
done
