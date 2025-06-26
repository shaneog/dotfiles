#!/usr/bin/env zsh

if [ -f ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock ]; then
  export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
fi
