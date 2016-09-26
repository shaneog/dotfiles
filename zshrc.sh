# Check if zplug is installed
if [[ ! -d ~/.zplug ]]; then
  git clone --depth 1 --branch prezto https://github.com/zplug/zplug ~/.zplug
  source ~/.zplug/init.zsh && zplug update --self
fi

# Essential
source ~/.zplug/init.zsh

# Make sure to use double quotes to prevent shell expansion
zplug "zsh-users/zsh-completions"
zplug "zsh-users/zsh-syntax-highlighting", nice:10
zplug "zsh-users/zsh-history-substring-search", nice:12

# Prezto modules
zplug 'modules/environment', from:prezto
zplug 'modules/terminal', from:prezto
zplug 'modules/editor', from:prezto
zplug 'modules/history', from:prezto
zplug 'modules/directory', from:prezto
zplug 'modules/spectrum', from:prezto
zplug 'modules/utility', from:prezto
zplug 'modules/completion', from:prezto
zplug 'modules/homebrew', from:prezto
zplug 'modules/git', from:prezto
zplug 'modules/osx', from:prezto
zplug 'modules/ruby', from:prezto
zplug 'modules/rails', from:prezto
zplug 'modules/tmux', from:prezto
zplug 'modules/prompt', from:prezto

# Tmux
alias tmux="tmux -f ${HOME}/.config/tmux/tmux.conf"


# Prezto configuration options
zstyle ':prezto:*:*' color 'yes'
zstyle ':prezto:module:editor' dot-expansion 'yes'
zstyle ':prezto:module:prompt' theme 'sorin'
zstyle ':prezto:module:terminal' auto-title 'yes'
zstyle ':prezto:module:tmux:auto-start' local 'yes'
zstyle ':prezto:module:tmux:auto-start' remote 'yes'
zstyle ':prezto:module:tmux:iterm' integrate 'no'


# Install packages that have not been installed yet
if ! zplug check --verbose; then
  echo; zplug install
fi

zplug load

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor root)
# zsh-history-substring-search
zmodload zsh/terminfo
bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Google Cloud SDK.
source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc"
