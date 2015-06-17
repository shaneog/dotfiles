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
