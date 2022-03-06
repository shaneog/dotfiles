#
# Executes commands at login before zshrc.

# Set locale correctly
if [[ -z "$LANG" ]]; then
    export LANG='en_US.UTF-8'
    export LANGUAGE=en_US.UTF-8
fi

export LC_COLLATE=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export LC_MESSAGES=en_US.UTF-8
export LC_MONETARY=en_US.UTF-8
export LC_NUMERIC=en_US.UTF-8
export LC_TIME=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LESSCHARSET=utf-8

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath path

# Zsh search path for executables
path=(
  /usr/local/{bin,sbin}
  $path
)
