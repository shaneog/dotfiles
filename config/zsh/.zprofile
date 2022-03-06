#
# Executes commands at login before zshrc.

# Set locale correctly
if [[ -z "$LANG" ]]; then
  LANG='en_US.UTF-8'
  LANGUAGE=$LANG
fi

LC_COLLATE=$LANG
LC_CTYPE=$LANG
LC_MESSAGES=$LANG
LC_MONETARY=$LANG
LC_NUMERIC=$LANG
LC_TIME=$LANG
LC_ALL=$LANG

LESSCHARSET=utf-8

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath path

# Zsh search path for executables
path=(
  /usr/local/{bin,sbin}
  $path
)
