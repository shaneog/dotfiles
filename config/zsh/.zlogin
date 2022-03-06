#!/usr/bin/env zsh

# Execute code that does not affect the current session in the background.
(
    setopt LOCAL_OPTIONS EXTENDED_GLOB
    autoload -U zrecompile

    # Compile zcompdump, if modified, to increase startup speed.
    ZSH_COMPDUMP="${ZSH_COMPDUMP:-${XDG_CACHE_HOME:-${ZSH_CACHE_DIR:-$HOME/.cache}/zsh}/zcompdump}"

    if [[ -s "$ZSH_COMPDUMP" && (! -s "${ZSH_COMPDUMP}.zwc" || "$ZSH_COMPDUMP" -nt "${ZSH_COMPDUMP}.zwc") ]]; then
        zrecompile -pq "$ZSH_COMPDUMP"
    fi
    # zcompile .zshrc
    zrecompile -pq ${ZDOTDIR:-${HOME}}/.zshrc
    zrecompile -pq ${ZDOTDIR:-${HOME}}/.zprofile
    zrecompile -pq ${ZDOTDIR:-${HOME}}/.zshenv
    # recompile all zsh or sh
    for f in $ZDOTDIR/**/*.*sh
    do
        zrecompile -pq $f
    done
) &!
