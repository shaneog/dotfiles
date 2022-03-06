#!/usr/bin/env zsh

zinit ice wait atload"_zsh_autosuggest_start" lucid
zinit load zsh-users/zsh-autosuggestions

export ZSH_AUTOSUGGEST_USE_ASYNC=1

zinit ice wait lucid
zinit load zsh-users/zsh-completions

zinit ice wait lucid
zinit load zsh-users/zsh-syntax-highlighting

# must load directly otherwise bindkeys won't work
zinit load zsh-users/zsh-history-substring-search

zstyle ":history-search-multi-word" page-size "11"
zinit ice wait"1" lucid
zinit load zdharma-continuum/history-search-multi-word

# Ignore gitignore with fzf
export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules}/*" 2> /dev/null'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

zinit ice from"gh-r" as"program" bpick"*arm*"
zinit load junegunn/fzf

zinit ice wait lucid
zinit load djui/alias-tips
export ZSH_PLUGINS_ALIAS_TIPS_TEXT="💡  Try: "

#
# Prezto
#
zinit snippet PZT::modules/helper/init.zsh

# Prezto Settings
zstyle ':prezto:*:*' color 'yes'
zstyle ':prezto:module:editor' dot-expansion 'yes'
zstyle ':prezto:module:terminal' auto-title 'yes'
zstyle ':prezto:module:tmux:iterm' integrate 'no'
zstyle ':prezto:module:utility' correct 'no'
zstyle ':prezto:module:utility' safe-ops 'no'

# Prezto modules
zinit snippet PZTM::environment
zinit snippet PZTM::terminal
zinit snippet PZTM::editor
zinit snippet PZTM::directory
zinit snippet PZTM::spectrum
zinit snippet PZTM::gnu-utility

zinit ice svn; zinit snippet PZTM::utility
zinit ice svn blockf \
            atclone"git clone --recursive https://github.com/zsh-users/zsh-completions.git external"
zinit snippet PZTM::completion
zinit snippet PZTM::homebrew
zinit ice svn; zinit snippet PZTM::git
zinit ice svn; zinit snippet PZTM::osx
zinit snippet PZTM::tmux


zinit ice wait lucid
zinit load greymd/docker-zsh-completion

zinit load spaceship-prompt/spaceship-prompt

export SPACESHIP_GIT_STATUS_PREFIX=" "
export SPACESHIP_GIT_STATUS_SUFFIX=""
export SPACESHIP_GIT_STATUS_ADDED="%F{yellow}•%F{red}"
export SPACESHIP_GIT_STATUS_UNTRACKED="%F{blue}•%F{red}"
export SPACESHIP_GIT_STATUS_DELETED="%F{red}•%F{red}"
export SPACESHIP_GIT_STATUS_MODIFIED="%F{green}•%F{green}"

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor root)

# zsh-history-substring-search
zmodload zsh/terminfo
[ -n "${terminfo[kcuu1]}" ] && bindkey "${terminfo[kcuu1]}" history-substring-search-up
[ -n "${terminfo[kcud1]}" ] && bindkey "${terminfo[kcud1]}" history-substring-search-down
bindkey -M emacs '^P' history-substring-search-up
bindkey -M emacs '^N' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
