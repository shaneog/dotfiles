#!/usr/bin/env zsh

# direnv comes from the Brewfile; its hook is cached rather than regenerated,
# so startup neither shells out nor downloads a release binary.
cached_init direnv direnv hook zsh && source $REPLY
