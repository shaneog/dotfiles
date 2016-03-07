#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

eval "$(hub alias -s)"

# Postgres App
export PATH=/Applications/Postgres.app/Contents/Versions/9.4/bin:$PATH

# Go
export PATH=$PATH:/usr/local/opt/go/libexec/bin

# Travis CLI
[ -f $HOME/.travis/travis.sh ] && source $HOME/.travis/travis.sh

# Android Platform
export PATH=$PATH:$HOME/Library/Android/sdk/platform-tools

# Use nvm because NodeJS is now releasing so rapidly
export NVM_DIR=~/.nvm
source $(brew --prefix nvm)/nvm.sh

# fzf shell bindings + completion
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# custom scripts
export PATH=$PATH:$HOME/.bin

# Docker environment vars
if [ "$(docker-machine status default)" == "Running" ]; then
  eval "$(docker-machine env default)"
fi
# The next line updates PATH for the Google Cloud SDK.
source '/Users/shane/google-cloud-sdk/path.zsh.inc'

# The next line enables shell command completion for gcloud.
source '/Users/shane/google-cloud-sdk/completion.zsh.inc'

