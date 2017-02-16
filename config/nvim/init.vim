" ##############################################################################
" ### Author : Shane O'Grady <shane@ogrady.ie>                               ###
" ##############################################################################
" ### Neovim Configuration                                                   ###
" ### Date created : Monday 10 October 2016.                                 ###
" ##############################################################################

let $NVIM_TUI_ENABLE_TRUE_COLOR=1

if !filereadable(expand('~/.config/nvim/autoload/plug.vim'))
  silent !curl -fLo "$HOME/.config/nvim/autoload/plug.vim" --create-dirs
    \ 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall | source $MYVIMRC
endif

call plug#begin('~/.config/nvim/plugged')

  " Plugins {
  Plug '$HOME/.zplug/bin/fzf' | Plug 'junegunn/fzf.vim'
  Plug 'vim-airline/vim-airline'
  " }

call plug#end()

if has('autocmd')
  filetype plugin indent on
endif
if has('syntax') && !exists('g:syntax_on')
  syntax enable
endif

" Map the leader key to [space]
let mapleader="\<SPACE>"
