# Locale
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

# XDG
export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache
export XDG_DATA_HOME=$HOME/.local/share

# zsh config
export ZSH_CACHE_DIR=$XDG_CACHE_HOME/zsh
# TODO: Fix these; Prezto doesn't respect these vars
export HISTFILE=$XDG_DATA_HOME/zsh/zhistory
export ZSH_COMPDUMP=$ZSH_CACHE_DIR/zcompdump
