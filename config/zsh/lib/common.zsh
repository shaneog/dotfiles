#!/usr/bin/env zsh

##
# Plugins
##
zinit ice ver"$DOTFILES_PINS[zsh-users/zsh-completions]"
zinit light zsh-users/zsh-completions

# Highlighting is zsh-patina's, activated at the end of .zshrc. A base layer may
# load zsh-syntax-highlighting on the same ZLE hook, which is not ours to
# uninstall, so the patina block stands it down instead.
#
# Autosuggestions are a different widget, and still ours unless something else
# got there first -- two of those fight over the line editor just the same.
if (( ! $+functions[_zsh_autosuggest_start] )); then
	# atload starts it by hand: deferred loading misses the precmd hook it
	# normally relies on.
	zinit ice wait lucid ver"$DOTFILES_PINS[zsh-users/zsh-autosuggestions]" atload"_zsh_autosuggest_start"
	zinit light zsh-users/zsh-autosuggestions
fi

# The plugin's default is colour 8, the usual dim grey. Gotham makes that slot a
# shade of the background -- tmux.conf fills the status line with it -- so a
# suggestion drawn in it cannot be read. 242 is from the fixed part of the
# 256-colour table, so it is the same grey under any profile.
#
# Outside the guard: the palette is this repo's whoever loaded the plugin.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'

# http://zshwiki.org/home/config/prompt
# enable colors and predefined variables
autoload -Uz colors && colors

##
# Options
##

# Directories
setopt AUTO_CD              # A directory typed as a command is a cd to it.
setopt AUTO_PUSHD           # Every cd pushes the old directory onto the stack.
setopt PUSHD_IGNORE_DUPS    # ...once.
setopt PUSHD_SILENT         # Do not print the stack after pushd or popd.
setopt PUSHD_TO_HOME        # pushd with no argument goes home.
setopt CDABLE_VARS          # cd to a directory a variable names.
unsetopt CLOBBER            # > does not overwrite a file. >! does.

# Jobs
setopt LONG_LIST_JOBS       # List jobs in the long format.
setopt AUTO_RESUME          # A command that names a suspended job resumes it.
unsetopt BG_NICE            # Background jobs keep their priority.
unsetopt HUP                # ...and are not killed when the shell exits,
unsetopt CHECK_JOBS         # which does not stop to ask about them either.

# The command line
setopt COMBINING_CHARS      # Draw an accent with the character it combines with.
setopt INTERACTIVE_COMMENTS # A # starts a comment at the prompt too.
setopt RC_QUOTES            # '' inside single quotes is one quote.

# Spelling correction, for the command and not its arguments.
setopt CORRECT

##
# Environment
##

# Exported, so child processes (sudoedit, crontab, tools that shell out to a
# pager) see them too.
export EDITOR="nvim"
export VISUAL="$EDITOR"
export PAGER="less"

# Default less options
# Mouse-wheel scrolling has been disabled by -X (disable screen clearing).
export LESS="-F -g -i -M -R -S -w -X -z-4"

# Colour in man pages. less draws bold, underline and standout with whatever
# these say, and a man page is written in nothing else.
export LESS_TERMCAP_mb=$'\E[01;31m'      # Blinking, which nothing uses: bold red.
export LESS_TERMCAP_md=$'\E[01;31m'      # Bold: headings and option names.
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_so=$'\E[00;47;30m'   # Standout: the status line and search hits.
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'      # Underline: arguments.
export LESS_TERMCAP_ue=$'\E[0m'

# zsh has a builtin called log, which is found before macOS's /usr/bin/log.
# /etc/zshrc disables it for that reason, and `noglobalrcs` skips that file.
[[ -x /usr/bin/log ]] && disable log
