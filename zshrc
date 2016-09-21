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
export PATH=/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH

# Go
export PATH=$PATH:/usr/local/opt/go/libexec/bin

# Travis CLI
[ -f $HOME/.travis/travis.sh ] && source $HOME/.travis/travis.sh

# Android Platform
export PATH=$PATH:$HOME/Library/Android/sdk/platform-tools

# fzf shell bindings + completion
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# custom scripts
export PATH=$PATH:$HOME/.bin

# The next line updates PATH for the Google Cloud SDK.
source '/Users/shane/google-cloud-sdk/path.zsh.inc'

# The next line enables shell command completion for gcloud.
source '/Users/shane/google-cloud-sdk/completion.zsh.inc'

