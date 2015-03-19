" Plugins
call plug#begin('~/.vim/bundle')
"  ----------------------------------------------------------------
"  Colorschemes
"  ----------------------------------------------------------------
Plug 'junegunn/seoul256.vim'
Plug 'croaky/vim-colors-github'
Plug 'altercation/vim-colors-solarized'
"  ----------------------------------------------------------------

Plug 'junegunn/vim-easy-align'
Plug 'junegunn/vim-emoji'
Plug 'junegunn/vim-xmark', { 'do': 'make' }
Plug 'scrooloose/syntastic'
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-vinegar'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rails'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-haml'
Plug 'tpope/vim-bundler'
Plug 'tpope/vim-rake'
Plug 'ngmy/vim-rubocop'
Plug 'vim-ruby/vim-ruby'
Plug 'ludovicchabant/vim-gutentags'
Plug 'majutsushi/tagbar'
Plug 'airblade/vim-gitgutter'
Plug 'bling/vim-airline'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'kchmck/vim-coffee-script'
Plug 'pangloss/vim-javascript'
Plug 'elzr/vim-json'
Plug 'editorconfig/editorconfig-vim'
Plug 'kristijanhusak/vim-multiple-cursors'
Plug 'majutsushi/tagbar'
Plug 'othree/html5.vim'
Plug 'hail2u/vim-css3-syntax'
call plug#end()

command! Reload :so test.vimrc