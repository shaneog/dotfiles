#!/usr/bin/env zsh

##
# Plugins
##
zinit light zsh-users/zsh-completions

# Highlighting is zsh-patina's, activated at the end of .zshrc:
# fast-syntax-highlighting used to be loaded here and is gone. A base layer may
# still load zsh-syntax-highlighting on the same ZLE hook, which is not ours to
# uninstall, so the patina block stands it down instead.
#
# Autosuggestions are a different widget, and still ours unless something else
# got there first -- two of those fight over the line editor just the same.
if (( ! $+functions[_zsh_autosuggest_start] )); then
	# atload starts it by hand: deferred loading misses the precmd hook it
	# normally relies on.
	zinit ice wait lucid atload"_zsh_autosuggest_start"
	zinit light zsh-users/zsh-autosuggestions
fi

# http://zshwiki.org/home/config/prompt
# enable colors and predefined variables
autoload -Uz colors && colors

##
# Prezto
##

# Prezto Settings
zstyle ':prezto:*:*' color 'yes'
zstyle ':prezto:module:editor' dot-expansion 'yes'
zstyle ':prezto:module:terminal' auto-title 'yes'
zstyle ':prezto:module:tmux:iterm' integrate 'no'
zstyle ':prezto:module:utility' correct 'no'
zstyle ':prezto:module:utility' safe-ops 'no'

# Prezto modules
zinit for \
  PZTM::environment \
  PZTM::terminal \
  PZTM::editor \
  PZTM::directory \
  PZTM::spectrum \
  PZTM::gnu-utility
# Deferred: 22ms of the startup went here, and it is aliases and helper
# functions -- nothing that can matter before the first prompt is drawn.
zinit ice wait lucid
zinit snippet PZTM::utility
zinit ice blockf \
  atclone"git clone -q --depth=1 https://github.com/zsh-users/zsh-completions.git external"
zinit snippet PZTM::completion

##
# Configuration
##

# Enable zsh corrections
setopt CORRECT

# Environment. Exported, so child processes (sudoedit, crontab, tools that
# shell out to a pager) see them too.
export EDITOR="nvim"
export VISUAL="$EDITOR"
export PAGER="less"

# Default less options
# Mouse-wheel scrolling has been disabled by -X (disable screen clearing).
export LESS="-F -g -i -M -R -S -w -X -z-4"

# Fix for https://openradar.appspot.com/27348363
#
# Backgrounded: it is a subprocess costing 8ms of every shell start, and nothing
# in the rest of startup waits on the keys being loaded.
(ssh-add --apple-load-keychain &) 2>/dev/null
