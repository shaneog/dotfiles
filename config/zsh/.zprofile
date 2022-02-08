# Set homebrew shellenv for M1 Macs
[ -d "/opt/homebrew" ] && eval "$(/opt/homebrew/bin/brew shellenv)"

# Disable zsh_sessions since we use tmux restore
export SHELL_SESSIONS_DISABLE=1
