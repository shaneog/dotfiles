#!/usr/bin/env zsh

# Route SSH auth through 1Password's agent. Skipped inside an inbound SSH
# session, where SSH_AUTH_SOCK is likely a forwarded agent and taking it over
# would break authentication with the keys the client forwarded.
if [[ -z "$SSH_CONNECTION" ]] \
  && [[ -S ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock ]]; then
  export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
fi
