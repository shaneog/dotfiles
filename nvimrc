" Load vim-plug
if filereadable(expand("~/.vim/autoload/plug.vim"))
  source ~/.vim/autoload/plug.vim
endif

" Use Vim settings
if filereadable(expand("~/.vimrc"))
  source ~/.vimrc
endif