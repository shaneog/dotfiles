#!/usr/bin/env zsh

# Docker's own CLI emits its completion, so no plugin is needed. The previous one
# cost 20ms of every shell start, loaded whether or not docker was installed, and
# vendored a copy of upstream's completion from whenever it last synced -- this
# tracks the installed version instead, and costs nothing until you press tab.
cached_completion docker docker completion zsh
