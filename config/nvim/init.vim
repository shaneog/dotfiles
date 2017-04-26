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

if filereadable(expand("~/.config/nvim/plugs.vim"))
  source ~/.config/nvim/plugs.vim
endif

if has('autocmd')
  filetype plugin indent on
endif

if has('syntax') && !exists('g:syntax_on')
  syntax enable
endif

" Map the leader key to [space]
let mapleader="\<SPACE>"

" Color scheme
set background=dark
silent! colorscheme gotham

" Enable line numbers
set relativenumber
set number

" Use ripgrep as vimgrep
set grepprg=rg\ --vimgrep

" ============================================================================================================
" Plugin specific settings
" ============================================================================================================
if filereadable(expand("~/.config/nvim/settings.vim"))
  source ~/.config/nvim/settings.vim
endif
