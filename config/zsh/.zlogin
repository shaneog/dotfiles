#!/usr/bin/env zsh

# Opt out of background compilation. The recompile runs detached, so a .zwc can
# land a moment after you edit one of these files, and zsh prefers a .zwc that
# is not *older* than its source -- meaning the next shell can run the stale
# compiled copy. Set this while editing zsh config, and in tests.
[[ -n "$ZSH_NO_ZCOMPILE" ]] && return

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
