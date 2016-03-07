" ##############################################################################
" ### Author : Shane O'Grady <shane@ogrady.ie>                               ###
" ##############################################################################
" ### Vim Configuration                                                      ###
" ### Date created : Sunday 22 March 2015 04:12 UTC                          ###
" ##############################################################################


" Use Vim settings, rather then Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
if has('vim_starting')
  if &compatible
    set nocompatible
  endif
endif

" enable syntax highlighting
syntax enable

" Turn off modelines
set modelines=0

" install plugins
if filereadable(expand("~/.vim/bundles.vim"))
  source ~/.vim/bundles.vim
endif

filetype plugin indent on

" Use the OS clipboard by default (on versions compiled with `+clipboard`)
set clipboard=unnamed
" Enhance command-line completion
set wildmenu
set wildmode=list:longest,list:full
" Allow cursor keys in insert mode
set esckeys
" Allow backspace in insert mode
set backspace=indent,eol,start
" Optimize for fast terminal connections
set ttyfast
" Add the g flag to search/replace by default
set gdefault
" Use UTF-8 without BOM
set encoding=utf-8 nobomb
" Don’t add empty newlines at the end of files (by default)
set binary
set noeol

" Centralize backups, swapfiles and undo history
silent !mkdir ~/.vim/tmp > /dev/null 2>&1
silent !mkdir ~/.vim/undo > /dev/null 2>&1
set undodir=~/.vim/undo
set directory=~/.vim/tmp  " Set temp directory (don't litter local dir with swp/tmp files)
set nobackup              " Get rid of backups
set nowb                  " Get rid of backups on write
set noswapfile            " Get rid of swp files
if exists("&undodir")
  set undofile          " Persistent undo
  set undolevels=500
  set undoreload=500
endif

"Store lots of :cmdline history
set history=1000

" Enable line numbers
set number
set numberwidth=5
" Switch syntax highlighting on, when the terminal has colors
" Also switch on highlighting the last used search pattern.
if (&t_Co > 2 || has("gui_running")) && !exists("syntax_on")
  syntax on
endif
" Highlight current line
set cursorline
" Highlight current column
set cursorcolumn
" Softtabs, 2 spaces
set tabstop=2
set shiftwidth=2
set smarttab
set expandtab

" Highlight searches
set hlsearch
" Ignore case of searches
set ignorecase
" Highlight dynamically as pattern is typed
set incsearch
"No sounds
set visualbell
" Don’t reset cursor to start of line when moving around.
set nostartofline
" Show the cursor position
set ruler
" Don’t show the intro message when starting Vim
set shortmess=atI
" Show the current mode
set showmode
" Show the filename in the window titlebar
set title
" Show the (partial) command as it’s being typed
set showcmd

" always set autoindenting on
set autoindent
set smartindent
" Display extra whitespace
set list listchars=tab:»·,trail:·,nbsp:·

" Use relative line numbers
if exists("&relativenumber")
  set relativenumber
  au BufReadPost * set relativenumber
endif
" Start scrolling three lines before the horizontal window border
set scrolloff=3

" Use $ to show changes
set cpoptions+=$

" Automatic commands
if has("autocmd")
  " Enable file type detection
  filetype on
endif

" Folding
" fold based on indent
set foldmethod=indent
" deepest fold is 3 levels
set foldnestmax=3
" don't fold by default
set nofoldenable

" automatically rebalance windows on vim resize
autocmd VimResized * :wincmd =

" Color scheme
set background=dark
silent! colorscheme gotham
" set 256 color mode
if $TERM == 'xterm-256color' || 'screen-256color'
  set t_Co=256
endif

highlight Comment cterm=italic

" Switch wrap off for everything
set nowrap

" Make it obvious where 80 characters is
set textwidth=80
set colorcolumn=+1,110

if has('mouse')
  " Enable mouse in all modes
  set mouse=a
  "set selection=exclusive
  set selectmode=mouse,key
  set nomousehide
endif

" Open new split panes to right and bottom, which feels more natural
set splitbelow
set splitright

" Always use vertical diffs
set diffopt+=vertical


" --------------------
" Custom key mappings
" --------------------

" <Space> is the leader character
let mapleader = " "
" Tab completion
" will insert tab at beginning of line,
" will use completion if not at beginning
function! InsertTabWrapper()
    let col = col('.') - 1
    if !col || getline('.')[col - 1] !~ '\k'
        return "\<tab>"
    else
        return "\<c-p>"
    endif
endfunction
inoremap <Tab> <c-r>=InsertTabWrapper()<cr>
inoremap <S-Tab> <c-n>

" Switch between the last two files
nnoremap <leader><leader> <c-^>

" Get off my lawn
nnoremap <Left> :echoe "Use h"<CR>
nnoremap <Right> :echoe "Use l"<CR>
nnoremap <Up> :echoe "Use k"<CR>
nnoremap <Down> :echoe "Use j"<CR>

" Scroll the viewport faster
nnoremap <C-e> 3<C-e>
nnoremap <C-y> 3<C-y>

" Run commands that require an interactive shell
nnoremap <Leader>r :RunInInteractiveShell<space>

" ============================================================================================================
" Filetype specific settings
" ============================================================================================================
"{{{
autocmd FileType php setlocal tabstop=2 shiftwidth=2 softtabstop=2 textwidth=110
autocmd FileType ruby setlocal tabstop=2 shiftwidth=2 softtabstop=2 textwidth=110
autocmd FileType coffee,javascript setlocal tabstop=2 shiftwidth=2 softtabstop=2 textwidth=110
autocmd FileType python setlocal tabstop=4 shiftwidth=4 softtabstop=4 textwidth=110
autocmd FileType html,htmldjango,xhtml,haml setlocal tabstop=2 shiftwidth=2 softtabstop=2 textwidth=0
autocmd FileType sass,scss,css setlocal tabstop=2 shiftwidth=2 softtabstop=2 textwidth=110
autocmd FileType snippets setlocal tabstop=4 shiftwidth=4 softtabstop=4 textwidth=110
autocmd FileType vim setlocal keywordprg=:help tabstop=2 shiftwidth=2 softtabstop=2 textwidth=110

" md is markdown
autocmd BufRead,BufNewFile *.md set filetype=markdown
autocmd BufRead,BufNewFile *.md set spell
"}}}

" Treat <li> and <p> tags like the block tags they are
let g:html_indent_tags = 'li\|p'

" ============================================================================================================
" Custom scripts and autocommands
" ============================================================================================================
"{{{
" Close vim if the last open window is nerdtree
autocmd BufEnter * if (winnr("$") == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary") | q | endif

" Remove trailing whitespaces automatically before save
autocmd BufWritePre * :%s/\s\+$//e

" Autoreload settings files
augroup reload_vimrc " {
    autocmd!
    autocmd BufWritePost vimrc source $MYVIMRC
    " Also auto reload our bundles file
    autocmd BufWritePost bundles.vim source $MYVIMRC
    autocmd BufWritePost bundles.vim PlugInstall
augroup END " }
"}}}

" ============================================================================================================
" Plugin specific settings
" ============================================================================================================
"{{{
if filereadable(expand("~/.vim/settings.vim"))
  source ~/.vim/settings.vim
endif
"}}}