# Set up bash completion
if [ -f $(brew --prefix)/etc/bash_completion ]; then
. $(brew --prefix)/etc/bash_completion
fi

# Set up some sensible defaults
if [ -f /usr/local/bin/sensible.bash ]; then
   source /usr/local/bin/sensible.bash
fi

# Fix for https://openradar.appspot.com/27348363
ssh-add -A 2>/dev/null

#
# Aliases
#

# Git
alias g='git'

# Path
PATH=/usr/local/bin:$PATH; export PATH

# Use a local bashrc, if exists
if [[ -f "$HOME/.bashrc.local" ]]; then
  source "$HOME/.bashrc.local"
fi
