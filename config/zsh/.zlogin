#!/usr/bin/env zsh

# Compile the completion dump in the background, so it costs this shell nothing.
#
# Only the dump is compiled. The zsh sources used to be compiled here too, but
# that raced with editing them: zrecompile runs detached, so a .zwc could be
# written from content read before an edit, and zsh prefers a .zwc that is not
# *older* than its source -- so the next shell would run the stale compiled
# copy. Compiling them measured no faster anyway (210.9ms vs 215.1ms over 30
# runs, i.e. within noise), and it wrote build artefacts into the repo.
#
# The dump is safe to compile: it is machine-generated, nobody edits it, and it
# lives in the cache directory rather than the repo.
[[ -n "$ZSH_NO_ZCOMPILE" ]] && return

(
    setopt LOCAL_OPTIONS
    autoload -U zrecompile

    ZSH_COMPDUMP="${ZSH_COMPDUMP:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump}"

    if [[ -s "$ZSH_COMPDUMP" && (! -s "${ZSH_COMPDUMP}.zwc" || "$ZSH_COMPDUMP" -nt "${ZSH_COMPDUMP}.zwc") ]]; then
        zrecompile -pq "$ZSH_COMPDUMP"
    fi
) &!
