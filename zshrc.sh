# Check if zplug is installed
if [[ ! -d ~/.zplug ]]; then
  git clone --depth 1 https://github.com/zplug/zplug ~/.zplug
  source ~/.zplug/init.zsh && zplug update --self
fi

# Essential
source ~/.zplug/init.zsh

# Make sure to use double quotes to prevent shell expansion
zplug "zsh-users/zsh-completions"
zplug "zsh-users/zsh-history-substring-search"
zplug "zsh-users/zsh-syntax-highlighting", nice:10
zplug "plugins/aws", from:oh-my-zsh
zplug "plugins/brew", from:oh-my-zsh
zplug "plugins/bundler", from:oh-my-zsh
zplug "plugins/chruby", from:oh-my-zsh
zplug "plugins/docker", from:oh-my-zsh
zplug "plugins/git", from:oh-my-zsh, nice:10
zplug "plugins/gitfast", from:oh-my-zsh, nice:10
zplug "plugins/golang", from:oh-my-zsh
zplug "plugins/tmux", from:oh-my-zsh, nice:10

setopt prompt_subst
zplug "caiogondim/bullet-train-oh-my-zsh-theme"

# Install packages that have not been installed yet
if ! zplug check --verbose; then
  echo; zplug install
fi

zplug load

# Configure theme
BULLETTRAIN_TIME_SHOW=false

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Google Cloud SDK.
source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc"

# Tmux
alias tmux="tmux -f ${HOME}/.config/tmux/tmux.conf"