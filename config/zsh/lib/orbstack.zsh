#!/usr/bin/env zsh

# OrbStack provides the docker and kubectl CLIs as well as its own `orb`. The
# Brewfile installs it, and on a machine where a managed setup got there first
# these lines simply find the CLIs already present.
#
# Both emit their own completions, so nothing is vendored: this tracks whatever
# version is installed, and costs nothing until you press tab. Each line is a
# no-op when its CLI is absent.
cached_completion docker docker completion zsh
cached_completion orb orb completion zsh
