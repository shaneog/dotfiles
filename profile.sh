# source the users bashrc if it exists
# if [ -e "${HOME}/.bashrc" ] ; then
#   source "${HOME}/.bashrc"
# fi

# source the users zshrc if it exists
if [ -e "$HOME/.config/zsh/.zshrc" ] ; then
  source "${HOME}/.config/zsh/.zshrc"
fi